resource "google_dns_record_set" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = data.google_dns_managed_zone.tsujiura.dns_name
  type         = "A"
  ttl          = 10

  rrdatas = local.frontend_a_rrset
}

resource "google_dns_record_set" "tsujiura_wildcard_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = "*.${data.google_dns_managed_zone.tsujiura.dns_name}"
  type         = "A"
  ttl          = 10

  rrdatas = local.frontend_a_rrset
}

resource "google_dns_record_set" "tsujiura_acm_validation" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = local.acm_validation_record.name
  type         = local.acm_validation_record.type
  ttl          = 60

  rrdatas = [local.acm_validation_record.value]
}
