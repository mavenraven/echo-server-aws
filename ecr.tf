resource "aws_ecr_repository" "echo_server_repo" {
  name = "echo_server"
  force_delete = true
}
