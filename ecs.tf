resource "aws_ecs_cluster" "ecs_cluster" {
  name = "echo-server"
}

resource "aws_ecs_cluster_capacity_providers" "capacity_providers" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name = "echo-server-task"
  task_definition = aws_ecs_task_definition.dummy.arn
  cluster = aws_ecs_cluster.ecs_cluster.arn
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    container_name = "dummy"
    container_port = 80
    target_group_arn = aws_lb_target_group.blue.arn
  }

  network_configuration {
    subnets = [aws_subnet.subnet-private.id]
    security_groups = [aws_security_group.allow_tls.id]
  }
}

data "aws_iam_policy_document" "fargate_trust_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "fargate_create_log_groups_policy_document" {
  statement {
    effect = "Allow"

    actions = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "fargate_create_log_groups_policy" {
  policy = data.aws_iam_policy_document.fargate_create_log_groups_policy_document.json
}

resource "aws_iam_role" "fargate_iam_role" {
  name               = "Fargate"
  assume_role_policy = data.aws_iam_policy_document.fargate_trust_policy_document.json
}

resource "aws_iam_role_policy_attachment" "fargate_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.fargate_iam_role.name
}

resource "aws_iam_role_policy_attachment" "fargate_create_logs" {
  policy_arn = aws_iam_policy.fargate_create_log_groups_policy.arn
  role       = aws_iam_role.fargate_iam_role.name
}


# For whatever reason, AWS requires that an ECS service is provisioned with a task definition
# when the deployment controller is CODE_DEPLOY. So, this task definition just "primes the pump"
# before the first actual deployment through code deploy. We don't even actually ever run it.
resource "aws_ecs_task_definition" "dummy" {
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.fargate_iam_role.arn

  container_definitions = jsonencode([
    {
      name = "dummy"
      image = "public.ecr.aws/docker/library/nginx"
      memory = 512
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = "echo-server"
          awslogs-create-group = "true"
          awslogs-region = "us-east-2"
          awslogs-stream-prefix = "echo-server"
        }
      }
    }

  ])
  family = "echo-server-task-definition"
}