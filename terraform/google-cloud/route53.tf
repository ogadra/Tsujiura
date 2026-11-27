resource "aws_route53_record" "tsujiura_dns_authorization" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  zone_id = data.aws_route53_zone.tsujiura.zone_id
  name    = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].name
  type    = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].type
  ttl     = 10

  records = [google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].data]
}
