resource "google_project_service" "certificatemanager" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = true
}

resource "google_certificate_manager_dns_authorization" "frontend" {
  name   = "tsujiura-frontend"
  domain = local.domain_name

  labels = local.common_labels

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate" "frontend" {
  name = "tsujiura-frontend"

  managed {
    domains            = [local.domain_name, "*.${local.domain_name}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.frontend.id]
  }

  labels = local.common_labels

  depends_on = [
    aws_route53_record.tsujiura_dns_authorization,
    google_dns_record_set.tsujiura_dns_authorization,
  ]
}

resource "google_certificate_manager_certificate_map" "frontend" {
  name = "tsujiura-frontend"

  labels = local.common_labels

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate_map_entry" "frontend" {
  name         = "tsujiura-frontend"
  map          = google_certificate_manager_certificate_map.frontend.name
  hostname     = local.domain_name
  certificates = [google_certificate_manager_certificate.frontend.id]

  labels = local.common_labels
}

resource "google_certificate_manager_certificate_map_entry" "frontend_wildcard" {
  name         = "tsujiura-frontend-wildcard"
  map          = google_certificate_manager_certificate_map.frontend.name
  hostname     = "*.${local.domain_name}"
  certificates = [google_certificate_manager_certificate.frontend.id]

  labels = local.common_labels
}
