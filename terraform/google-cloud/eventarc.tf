resource "google_project_service" "eventarc" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "eventarc.googleapis.com"
  disable_on_destroy = true
}
