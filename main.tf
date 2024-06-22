provider "aws" {
  region = "us-east-2"
}
data "aws_region" "current" {
}

variable "github_repo_url" {
  type = string
  default = "https://github.com/mavenraven/echo-server.git"
}


