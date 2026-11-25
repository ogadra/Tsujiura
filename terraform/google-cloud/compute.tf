resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = true
}

resource "google_compute_backend_bucket" "frontend" {
  name        = "tsujiura-frontend"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true

  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
  }

  depends_on = [google_project_service.compute]
}

resource "google_compute_url_map" "frontend" {
  name            = "tsujiura-frontend"
  default_service = google_compute_backend_bucket.frontend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "frontend"
  }

  path_matcher {
    name            = "frontend"
    default_service = google_compute_backend_bucket.frontend.id

    path_rule {
      paths   = ["/api/result"]
      service = google_compute_backend_service.result_api.id
    }
  }
}

resource "google_compute_global_address" "frontend" {
  name = "tsujiura-frontend"

  depends_on = [google_project_service.compute]
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
