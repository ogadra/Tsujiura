data "google_project" "current" {}

data "google_client_config" "current" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "tsujiura" {
  name = local.domain_name
}

data "google_dns_managed_zone" "tsujiura" {
  name = replace(local.domain_name, ".", "-")
}
