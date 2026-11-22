resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = true
}
