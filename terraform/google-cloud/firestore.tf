resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  disable_on_destroy = true
}

resource "google_firestore_database" "tsujiura" {
  name        = "(default)"
  location_id = "asia-northeast1"
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.firestore]
}

resource "google_firestore_field" "results_expires_at" {
  database   = google_firestore_database.tsujiura.name
  collection = "results"
  field      = "expiresAt"

  ttl_config {}

  # TTL field does not need single-field indexes.
  index_config {}
}
