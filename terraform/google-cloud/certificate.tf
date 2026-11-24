resource "google_project_service" "certificatemanager" {
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = true
}

resource "google_certificate_manager_dns_authorization" "frontend" {
  name   = "tsujiura-frontend"
  domain = local.domain_name

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate" "frontend" {
  name = "tsujiura-frontend"

  managed {
    domains            = [local.domain_name, "*.${local.domain_name}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.frontend.id]
  }
}

resource "google_certificate_manager_certificate_map" "frontend" {
  name = "tsujiura-frontend"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate_map_entry" "frontend" {
  name         = "tsujiura-frontend"
  map          = google_certificate_manager_certificate_map.frontend.name
  hostname     = local.domain_name
  certificates = [google_certificate_manager_certificate.frontend.id]
}

resource "google_certificate_manager_certificate_map_entry" "frontend_wildcard" {
  name         = "tsujiura-frontend-wildcard"
  map          = google_certificate_manager_certificate_map.frontend.name
  hostname     = "*.${local.domain_name}"
  certificates = [google_certificate_manager_certificate.frontend.id]
}

resource "google_compute_target_https_proxy" "frontend" {
  name            = "tsujiura-frontend"
  url_map         = google_compute_url_map.frontend.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.frontend.id}"
}

resource "google_compute_global_forwarding_rule" "frontend" {
  name       = "tsujiura-frontend"
  target     = google_compute_target_https_proxy.frontend.id
  ip_address = google_compute_global_address.frontend.address
  port_range = "443"
}
