resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_firestore_database" "main" {
  name        = "(default)"
  location_id = "asia-northeast1"
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.firestore]
}

resource "google_firestore_field" "results_expires_at" {
  database   = google_firestore_database.main.name
  collection = "results"
  field      = "expiresAt"

  # The ingest function writes expiresAt as a timestamp, one day after the query.
  ttl_config {}

  # TTL field does not need single-field indexes.
  index_config {}
}
