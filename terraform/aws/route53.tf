resource "aws_route53_query_log" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_log.arn
  zone_id                  = data.aws_route53_zone.tsujiura.zone_id
}

resource "aws_route53_record" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  # checkov:skip=CKV2_AWS_23:Points to the static IPs of Global Accelerator and the Google Cloud LB
  zone_id = data.aws_route53_zone.tsujiura.zone_id
  name    = local.domain_name
  type    = "A"
  ttl     = 10

  records = local.frontend_a_rrset
}

resource "aws_route53_record" "tsujiura_wildcard_a" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  # checkov:skip=CKV2_AWS_23:Points to the static IPs of Global Accelerator and the Google Cloud LB
  zone_id = data.aws_route53_zone.tsujiura.zone_id
  name    = "*.${local.domain_name}"
  type    = "A"
  ttl     = 10

  records = local.frontend_a_rrset
}

resource "aws_route53_record" "tsujiura_acm_validation" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id = data.aws_route53_zone.tsujiura.zone_id
  name    = local.acm_validation_record.name
  type    = local.acm_validation_record.type
  ttl     = 60

  records = [local.acm_validation_record.value]
}
