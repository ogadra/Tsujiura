resource "aws_route53_delegation_set" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
}

resource "aws_route53_zone" "tsujiura" {
  # checkov:skip=CKV2_AWS_38:Signing here alone would make resolvers reject the answers of the unsigned peer Cloud DNS zone
  # checkov:skip=CKV2_AWS_39:aws_route53_query_log.tsujiura attaches query logging under the same count
  count = local.route53_up ? 1 : 0

  name              = local.domain_name
  delegation_set_id = aws_route53_delegation_set.tsujiura.id

  tags = local.common_tags
}

resource "aws_route53_record" "tsujiura_apex_ns" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  count = local.route53_up ? 1 : 0

  zone_id         = aws_route53_zone.tsujiura[0].zone_id
  name            = local.domain_name
  type            = "NS"
  ttl             = 10
  allow_overwrite = true

  records = local.apex_ns_rrset

  lifecycle {
    precondition {
      condition     = length(distinct(local.apex_ns_rrset)) == 8
      error_message = "The apex NS RRset must hold 8 distinct name servers, 4 from each provider."
    }
  }
}

resource "aws_route53_query_log" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  count      = local.route53_up ? 1 : 0
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_log.arn
  zone_id                  = aws_route53_zone.tsujiura[0].zone_id
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
  for_each = local.route53_up ? local.frontend_ips : {}

  zone_id                          = aws_route53_zone.tsujiura[0].zone_id
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
  for_each = local.route53_up ? local.frontend_ips : {}

  zone_id                          = aws_route53_zone.tsujiura[0].zone_id
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
  count = local.route53_up ? 1 : 0

  zone_id = aws_route53_zone.tsujiura[0].zone_id
  name    = local.acm_validation_record.name
  type    = local.acm_validation_record.type
  ttl     = 10

  records = [local.acm_validation_record.value]
}

resource "aws_route53_record" "tsujiura_soa" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  count = local.route53_up ? 1 : 0

  zone_id         = aws_route53_zone.tsujiura[0].zone_id
  name            = local.domain_name
  type            = "SOA"
  ttl             = 10
  allow_overwrite = true

  records = ["ns-798.awsdns-35.net. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 10"]
}
