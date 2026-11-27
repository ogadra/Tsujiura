resource "aws_route53_zone" "tsujiura" {
  # checkov:skip=CKV2_AWS_38:Signing here alone would make resolvers reject the answers of the unsigned peer Cloud DNS zone
  # checkov:skip=CKV2_AWS_39:aws_route53_query_log.tsujiura attaches query logging to this zone
  name              = local.domain_name
  delegation_set_id = local.aws.route53_delegation_set_id

  tags = local.common_tags
}

resource "aws_route53_record" "tsujiura_apex_ns" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id         = aws_route53_zone.tsujiura.zone_id
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

resource "aws_route53_record" "tsujiura_soa" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id         = aws_route53_zone.tsujiura.zone_id
  name            = local.domain_name
  type            = "SOA"
  ttl             = 10
  allow_overwrite = true

  records = ["ns-798.awsdns-35.net. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 10"]
}

resource "aws_route53_record" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  # checkov:skip=CKV2_AWS_23:Points to the static IPs of Global Accelerator and the Google Cloud LB
  for_each = local.aws.frontend_ips

  zone_id                          = aws_route53_zone.tsujiura.zone_id
  name                             = local.domain_name
  type                             = "A"
  ttl                              = 10
  set_identifier                   = each.key
  multivalue_answer_routing_policy = true
  health_check_id                  = local.aws.route53_health_check_ids[each.key]

  records = [each.value]
}

resource "aws_route53_record" "tsujiura_wildcard_a" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  # checkov:skip=CKV2_AWS_23:Points to the static IPs of Global Accelerator and the Google Cloud LB
  for_each = local.aws.frontend_ips

  zone_id                          = aws_route53_zone.tsujiura.zone_id
  name                             = "*.${local.domain_name}"
  type                             = "A"
  ttl                              = 10
  set_identifier                   = each.key
  multivalue_answer_routing_policy = true
  health_check_id                  = local.aws.route53_health_check_ids[each.key]

  records = [each.value]
}

resource "aws_route53_record" "tsujiura_acm_validation" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id = aws_route53_zone.tsujiura.zone_id
  name    = local.aws.acm_validation_record.name
  type    = local.aws.acm_validation_record.type
  ttl     = 10

  records = [local.aws.acm_validation_record.value]
}

resource "aws_route53_record" "tsujiura_dns_authorization" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id = aws_route53_zone.tsujiura.zone_id
  name    = local.google_cloud.dns_authorization_record.name
  type    = local.google_cloud.dns_authorization_record.type
  ttl     = 10

  records = [local.google_cloud.dns_authorization_record.data]
}

resource "aws_route53_query_log" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  cloudwatch_log_group_arn = local.aws.route53_query_log_group_arn
  zone_id                  = aws_route53_zone.tsujiura.zone_id
}
