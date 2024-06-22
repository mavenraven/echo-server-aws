
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "codepipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

}

resource "aws_iam_role" "codepipeline_role" {
  name = "CodePipeline3"
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
resource "aws_iam_role_policy_attachment" "codepipeline_full_access_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

data "aws_iam_policy_document" "codepipeline_s3_policy_document" {
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
      aws_s3_bucket.codepipeline_bucket.arn,
      "${aws_s3_bucket.codepipeline_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "codepipline_s3_policy" {
  name = "CodePipelineS3Policy"
  policy = data.aws_iam_policy_document.codepipeline_s3_policy_document.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_s3_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipline_s3_policy.arn
}


resource "aws_codestarconnections_connection" "echo_server_codestarconnection" {
  name          = "echo_server_codestarconnection"
  provider_type = "GitHub"
}

data "aws_iam_policy_document" "codepipeline_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.echo_server_codestarconnection.arn]
  }
}

resource "aws_iam_policy" "codepipline_codestarconnection_policy" {
  name = "CodeStarConnectionPolicy"
  policy = data.aws_iam_policy_document.codepipeline_policy_document.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_codestarconnection_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipline_codestarconnection_policy.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_codebuild_dev_access_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}


resource "aws_codepipeline" "echo_server_pipeline" {
  name     = "echo_server_pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
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
        ConnectionArn = aws_codestarconnections_connection.echo_server_codestarconnection.arn
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
      output_artifacts = ["container_name"]

      configuration = {
        ProjectName = aws_codebuild_project.example.name
      }
    }
  }
}