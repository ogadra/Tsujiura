resource "aws_route53_query_log" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_log.arn
  zone_id                  = data.aws_route53_zone.tsujiura.zone_id
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

resource "aws_route53_record" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  # checkov:skip=CKV2_AWS_23:Points to the static IPs of Global Accelerator and the Google Cloud LB
  for_each = local.frontend_ips

  zone_id                          = data.aws_route53_zone.tsujiura.zone_id
  name                             = local.domain_name
  type                             = "A"
  ttl                              = 10
  set_identifier                   = each.key
  multivalue_answer_routing_policy = true
  health_check_id                  = aws_route53_health_check.tsujiura_frontend[each.key].id

  records = [each.value]
}

resource "aws_route53_record" "tsujiura_wildcard_a" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  # checkov:skip=CKV2_AWS_23:Points to the static IPs of Global Accelerator and the Google Cloud LB
  for_each = local.frontend_ips

  zone_id                          = data.aws_route53_zone.tsujiura.zone_id
  name                             = "*.${local.domain_name}"
  type                             = "A"
  ttl                              = 10
  set_identifier                   = each.key
  multivalue_answer_routing_policy = true
  health_check_id                  = aws_route53_health_check.tsujiura_frontend[each.key].id

  records = [each.value]
}

resource "aws_route53_record" "tsujiura_acm_validation" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id = data.aws_route53_zone.tsujiura.zone_id
  name    = local.acm_validation_record.name
  type    = local.acm_validation_record.type
  ttl     = 60

  records = [local.acm_validation_record.value]
}
