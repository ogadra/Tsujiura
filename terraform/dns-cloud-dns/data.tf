data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket
    key    = "tsujiura/aws/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "google_cloud" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket
    key    = "tsujiura/google-cloud/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
