data "aws_caller_identity" "current" {}

data "aws_route53_zone" "tsujiura" {
  name = local.domain_name
}
