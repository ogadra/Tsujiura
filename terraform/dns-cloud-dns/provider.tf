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
  region = "asia-northeast1"
}
