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
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs" #TODO: just re-use this since it has what we need
}

resource "aws_codebuild_project" "example" {
  name          = "example-build"
  service_role  = aws_iam_role.codebuild_role.arn
  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2

phases:
  build:
    commands:
      - docker build -t ${aws_ecr_repository.echo_server_repo.repository_url}:$CODEBUILD_RESOLVED_SOURCE_VERSION .
      - aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.echo_server_repo.repository_url}
      - docker push ${aws_ecr_repository.echo_server_repo.repository_url}:$CODEBUILD_RESOLVED_SOURCE_VERSION
      - m4 -D 'ECS_TASK_EXECUTION_ROLE_ARN=${aws_iam_role.fargate_iam_role.arn}' taskdef.json > temp && mv temp taskdef.json
      - echo "{\"name\":\"echo-server\", \"ImageURI\":\"${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-2.amazonaws.com/echo_server:$CODEBUILD_RESOLVED_SOURCE_VERSION\"}" > imageDetail.json
artifacts:
  files:
    - appspec.yaml
    - taskdef.json
    - imageDetail.json
  name: build_output
EOF
  }
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }
}


resource "aws_iam_role_policy_attachment" "codebuild_s3_policy_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codepipline_s3_policy.arn
}

