resource "google_project_service" "compute" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "compute.googleapis.com"
  disable_on_destroy = true
}

resource "google_compute_backend_bucket" "frontend" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name        = "tsujiura-frontend"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true

  cdn_policy {
    cache_mode = "FORCE_CACHE_ALL"
  }

  depends_on = [google_project_service.compute]
}

resource "google_compute_url_map" "frontend" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
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

  labels = local.common_labels

  depends_on = [google_project_service.compute]
}

resource "google_compute_target_https_proxy" "frontend" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name            = "tsujiura-frontend"
  url_map         = google_compute_url_map.frontend.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.frontend.id}"
}

resource "google_compute_global_forwarding_rule" "frontend" {
  name       = "tsujiura-frontend"
  target     = google_compute_target_https_proxy.frontend.id
  ip_address = google_compute_global_address.frontend.address
  port_range = "443"

  labels = local.common_labels
}

resource "google_compute_region_network_endpoint_group" "result_api" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name                  = "tsujiura-result-api"
  region                = data.google_client_config.current.region
  network_endpoint_type = "SERVERLESS"

  cloud_function {
    function = "tsujiura-result-api"
  }

  depends_on = [google_project_service.compute]
}

resource "google_compute_backend_service" "result_api" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name = "tsujiura-result-api"

  backend {
    group = google_compute_region_network_endpoint_group.result_api.id
  }
}
