resource "google_project_service" "pubsub" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "pubsub.googleapis.com"
  disable_on_destroy = true
}

resource "google_pubsub_topic" "dns_query_logs" {
  # checkov:skip=CKV_GCP_83:Google managed encryption is sufficient for this use case
  name = "dns-query-logs"

  labels = local.common_labels

  depends_on = [google_project_service.pubsub]
}
