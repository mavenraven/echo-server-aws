provider "aws" {
  region = "us-east-2"
}
data "aws_region" "current" {
}

variable "github_repo_url" {
  type = string
  default = "https://github.com/mavenraven/echo-server.git"
}

resource "aws_ecr_repository" "echo_server_repo" {
  name = "echo_server"
}

resource "aws_iam_role" "codebuild_role" {
  name = "CodeBuild"
  max_session_duration = 60 * 60
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_dev_access_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr_access_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "codebuild_cloudwatch_access_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs" # just re-use this since it has what we need
}

resource "aws_codebuild_project" "example" {
  name          = "example-build"
  service_role  = aws_iam_role.codebuild_role.arn
  source {
    type      = "GITHUB"
    location  = var.github_repo_url
    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      docker: 18
  build:
    commands:
      - echo "Building the Docker image..."
      - docker build -t ${aws_ecr_repository.echo_server_repo.repository_url}:latest .
      - $(aws ecr get-login --no-include-email --region ${data.aws_region.current.name})
      - docker push ${aws_ecr_repository.echo_server_repo.repository_url}:latest
EOF
  }
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }
}



