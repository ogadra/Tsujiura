resource "google_project_service" "cloudbuild" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = true
}
