resource "google_project_service" "run" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "run.googleapis.com"
  disable_on_destroy = true
}
