# ecr.tf

resource "aws_ecr_repository" "my_app_repo" {
  name = "my-app-repo"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.my_app_repo.repository_url
}
