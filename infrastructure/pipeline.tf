# pipeline.tf

# S3 bucket for storing CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.cluster_name}-codepipeline-artifacts"
  acl    = "private"
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "my_app_repo" {
  name = "my-app-repo"
}

# CodeBuild IAM role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.cluster_name}-codebuild-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "codebuild.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Attach policies to CodeBuild role
resource "aws_iam_role_policy_attachment" "codebuild_ecr_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "codebuild_kubernetes_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# CodeBuild project for building Docker images and pushing to ECR
resource "aws_codebuild_project" "app_build" {
  name          = "${var.cluster_name}-build"
  description   = "Builds Docker images and pushes them to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"  # CodeBuild image for Docker support
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true  # Required for Docker builds
    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.my_app_repo.repository_url
    }
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec.yml"  # Path to your buildspec.yml file
  }
}

# CodePipeline IAM role
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.cluster_name}-codepipeline-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "codepipeline.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Attach necessary policies to CodePipeline role
resource "aws_iam_role_policy_attachment" "codepipeline_s3_access" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecr_access" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# CodePipeline to automate Docker image build and deployment to EKS
resource "aws_codepipeline" "app_pipeline" {
  name     = "${var.cluster_name}-pipeline"
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
      provider         = "CodeCommit"  # Assuming CodeCommit as source control
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = var.codecommit_repository_name  # Replace with your CodeCommit repo name
        BranchName     = var.codecommit_branch
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
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"  # Placeholder, can change to custom deployment method
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ClusterName = var.cluster_name  # The EKS cluster name
        ServiceName = var.service_name  # Add your EKS service
      }
    }
  }
}

output "codepipeline_url" {
  value = aws_codepipeline.app_pipeline.id
}
