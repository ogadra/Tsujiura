resource "aws_route53_delegation_set" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
}

resource "aws_route53_health_check" "tsujiura_frontend" {
  for_each = local.frontend_ips

  type              = "HTTPS"
  ip_address        = each.value
  fqdn              = local.domain_name
  enable_sni        = true
  port              = 443
  resource_path     = "/healthz"
  request_interval  = 30
  failure_threshold = 3
  regions           = ["ap-northeast-1", "us-west-2", "eu-west-1"]

  tags = local.common_tags
}
