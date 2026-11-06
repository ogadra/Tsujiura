resource "google_project_service" "certificate_manager" {
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_certificate_manager_dns_authorization" "frontend" {
  name   = "tsujiura-frontend"
  domain = var.domain_name

  depends_on = [google_project_service.certificate_manager]
}

resource "google_certificate_manager_certificate" "frontend" {
  name = "tsujiura-frontend"

  managed {
    domains            = [var.domain_name]
    dns_authorizations = [google_certificate_manager_dns_authorization.frontend.id]
  }
}

resource "google_certificate_manager_certificate_map" "frontend" {
  name = "tsujiura-frontend"

  depends_on = [google_project_service.certificate_manager]
}

resource "google_certificate_manager_certificate_map_entry" "frontend" {
  name         = "tsujiura-frontend"
  map          = google_certificate_manager_certificate_map.frontend.name
  hostname     = var.domain_name
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

output "certificate_validation_cname_name" {
  description = "Name of the Google-managed certificate validation CNAME to pass to ogadra-net"
  value       = one(google_certificate_manager_dns_authorization.frontend.dns_resource_record).name
}

output "certificate_validation_cname_value" {
  description = "Value of the Google-managed certificate validation CNAME to pass to ogadra-net"
  value       = one(google_certificate_manager_dns_authorization.frontend.dns_resource_record).data
}

output "frontend_lb_ip" {
  description = "Static IP of the load balancer to pass to the frontend A records"
  value       = google_compute_global_address.frontend.address
}
