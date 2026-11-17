terraform {
  required_version = "= 1.17.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 8.11.0"
    }
  }
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
