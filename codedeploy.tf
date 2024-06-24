resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "ECS"
  name             = "echo_server"

}

data "aws_iam_policy_document" "codedeploy_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codedeploy_iam_role" {
  name               = "CodeDeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_policy_document.json
}

resource "aws_iam_role_policy_attachment" "aws_code_deploy_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_iam_role.name
}

resource "aws_iam_role_policy_attachment" "code_deploy_ecs_access_attachment" {
  role       = aws_iam_role.codedeploy_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_codedeploy_deployment_group" "codedeploy_deployment_group" {
  app_name = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name = "echo_server_deployment_group"
  service_role_arn = aws_iam_role.codedeploy_iam_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
    service_name = aws_ecs_service.ecs_service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.lb_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }



}