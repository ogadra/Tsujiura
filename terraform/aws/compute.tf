resource "google_compute_health_check" "tsujiura_frontend" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name                = "tsujiura-frontend"
  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  source_regions      = ["asia-northeast1", "us-central1", "europe-west1"]

  https_health_check {
    port         = 443
    request_path = "/healthz"
    host         = local.domain_name
  }
}
