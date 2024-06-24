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
    subnets = [aws_subnet.subnet-2b.id, aws_subnet.subnet-2b.id]
  }
}

data "aws_iam_policy_document" "fargate_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "fargate_iam_role" {
  name               = "Fargate"
  assume_role_policy = data.aws_iam_policy_document.fargate_policy_document.json
}

resource "aws_iam_role_policy_attachment" "fargate_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.fargate_iam_role.name
}

# Needed just for provisioning. CodePipeline will generate the actual definition dynamically.
resource "aws_ecs_task_definition" "dummy" {
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.fargate_iam_role.arn

  container_definitions = jsonencode([
    {
      name = "dummy"
      image = "471112551398.dkr.ecr.us-east-2.amazonaws.com/echo_server:d770a3ef66b636a6b2b76e798fd50a2f3703e2cd"
      memory = 512
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  family = "echo-server-task-definition"
}