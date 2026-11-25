resource "google_project_service" "artifactregistry" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = true
}
