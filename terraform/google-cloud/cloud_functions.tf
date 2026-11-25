resource "google_project_service" "cloudfunctions" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = true
}
