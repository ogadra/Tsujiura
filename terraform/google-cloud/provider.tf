terraform {
  required_version = ">= 1.17"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11"
    }
  }
}

provider "google" {
  project        = var.project_id
  region         = "asia-northeast1"
  default_labels = local.common_labels
}
