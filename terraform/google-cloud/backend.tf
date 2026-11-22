terraform {
  backend "s3" {
    key          = "tsujiura/google-cloud/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
