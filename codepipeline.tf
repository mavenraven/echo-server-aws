
resource "aws_s3_bucket" "codepipeline" {
  bucket = "codepipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

}

resource "aws_iam_role" "codepipeline" {
  name = "CodePipeline"
  max_session_duration = 60 * 60
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

#TODO: redudant now probably
resource "aws_iam_role_policy_attachment" "codepipeline_codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_codedeploy" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

data "aws_iam_policy_document" "codepipeline_s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.codepipeline.arn,
      "${aws_s3_bucket.codepipeline.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "codepipline_s3_policy" {
  name = "CodePipelineS3Policy"
  policy = data.aws_iam_policy_document.codepipeline_s3.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_s3" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipline_s3_policy.arn
}


resource "aws_codestarconnections_connection" "echo_server" {
  name          = "echo-server"
  provider_type = "GitHub"
}

data "aws_iam_policy_document" "codestar_connection" {
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.echo_server.arn]
  }
}

resource "aws_iam_policy" "codestar_connection" {
  name = "CodeStarConnectionPolicy"
  policy = data.aws_iam_policy_document.codestar_connection.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_codestar_connection" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codestar_connection.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_codebuild" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_codepipeline" "echo_server" {
  name     = "echo-server"
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    location = aws_s3_bucket.codepipeline.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn = aws_codestarconnections_connection.echo_server.arn
        FullRepositoryId = "mavenraven/echo-server"
        BranchName = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.echo_server.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeployToECS"
      version          = "1"
      input_artifacts  = ["build_output"]

      configuration = {
        ApplicationName = aws_codedeploy_app.echo_server.name
        DeploymentGroupName = aws_codedeploy_deployment_group.echo_server.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        AppSpecTemplateArtifact = "build_output"
        Image1ArtifactName = "build_output"
        #If you forget this, you just get an internal error from AWS!
        Image1ContainerName = "IMAGE1_NAME"
      }
    }
  }
}