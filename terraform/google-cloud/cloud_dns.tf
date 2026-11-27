resource "google_dns_record_set" "tsujiura_dns_authorization" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].type
  ttl          = 10

  rrdatas = [google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].data]
}
