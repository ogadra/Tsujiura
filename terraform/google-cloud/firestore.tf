resource "google_project_service" "firestore" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "firestore.googleapis.com"
  disable_on_destroy = true
}

resource "google_firestore_database" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name        = "(default)"
  location_id = data.google_client_config.current.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.firestore]
}

resource "google_firestore_field" "results_expires_at" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  database   = google_firestore_database.tsujiura.name
  collection = "results"
  field      = "expiresAt"

  ttl_config {}

  # TTL field does not need single-field indexes.
  index_config {}
}
