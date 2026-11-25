terraform {
  required_version = "= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.73.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "= 8.11.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "google" {
  region         = "asia-northeast1"
  default_labels = local.common_labels
}

provider "google" {
  alias                 = "billing"
  project               = data.google_project.current.project_id
  billing_project       = data.google_project.current.project_id
  user_project_override = true
}
