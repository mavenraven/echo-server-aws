provider "aws" {
  region = "us-east-2"
}
data "aws_region" "current" {
}

data "aws_caller_identity" "current" {}

variable "github_repo_url" {
  type = string
  default = "https://github.com/mavenraven/echo-server.git"
}

resource "aws_ecr_repository" "echo_server_repo" {
  name = "echo_server"
  force_delete = true
  image_tag_mutability = "IMMUTABLE"
}



