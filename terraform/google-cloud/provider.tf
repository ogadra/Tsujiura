terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.40"
    }
  }
}

provider "google" {
  project        = var.project_id
  region         = "asia-northeast1"
  default_labels = local.common_labels
}
