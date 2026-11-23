terraform {
  backend "s3" {
    key          = "tsujiura/aws/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
