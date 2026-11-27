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

data "aws_route53_zone" "parent" {
  name = local.parent_domain_name
}

data "aws_route53_records" "tsujiura_delegation" {
  zone_id    = data.aws_route53_zone.parent.zone_id
  name_regex = format("^%s\\.$", replace(local.domain_name, ".", "\\."))
}
