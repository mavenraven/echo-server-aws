resource "aws_ecs_cluster" "echo_server" {
  name = "echo-server"
}

resource "aws_ecs_service" "echo_server" {
  name = "echo-server"
  task_definition = aws_ecs_task_definition.initial.arn
  cluster = aws_ecs_cluster.echo_server.arn
  desired_count = 1

  capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    container_name = "initial"
    container_port = 80
    target_group_arn = aws_lb_target_group.blue.arn
  }

  network_configuration {
    subnets = [aws_subnet.subnet-private.id]
    security_groups = [aws_security_group.allow_http.id]
  }
}

data "aws_iam_policy_document" "fargate" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "create_log_group" {
  statement {
    effect = "Allow"

    actions = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "fargate_create_log_group" {
  policy = data.aws_iam_policy_document.create_log_group.json
}

resource "aws_iam_role" "fargate" {
  name               = "Fargate"
  assume_role_policy = data.aws_iam_policy_document.fargate.json
}

resource "aws_iam_role_policy_attachment" "fargate_ecs_task_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

resource "aws_iam_role_policy_attachment" "fargate_create_logs" {
  policy_arn = aws_iam_policy.fargate_create_log_group.arn
  role       = aws_iam_role.fargate.name
}


# For whatever reason, AWS requires that an ECS service is provisioned with a task definition
# when the deployment controller is CODE_DEPLOY. So, this task definition just "primes the pump"
# before the first actual deployment through code deploy.
resource "aws_ecs_task_definition" "initial" {
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.fargate.arn

  container_definitions = jsonencode([
    {
      name = "initial"
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
          awslogs-group = "initial-task"
          awslogs-create-group = "true"
          awslogs-region = "us-east-2"
          awslogs-stream-prefix = "initial-task"
        }
      }
    }

  ])
  family = "echo-server"
}