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


resource "aws_codedeploy_deployment_group" "codedeploy_deployment_group" {
  app_name = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name = "echo_server_deployment_group"
  service_role_arn = aws_iam_role.codedeploy_iam_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"


}