resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = true
}

resource "google_pubsub_topic" "dns_query_logs" {
  name = "dns-query-logs"

  depends_on = [google_project_service.pubsub]
}
