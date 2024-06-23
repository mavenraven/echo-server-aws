resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "ECS"
  name             = "echo_server"

}

resource "aws_codedeploy_deployment_config" "foo" {
  deployment_config_name = "echo_server_config"

  compute_platform = "ECS"

  traffic_routing_config {
    type = "AllAtOnce"
  }
}