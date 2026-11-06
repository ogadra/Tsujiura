resource "google_project_service" "log_sink" {
  for_each = toset(["logging.googleapis.com", "pubsub.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_pubsub_topic" "dns_query_logs" {
  name = "dns-query-logs"

  depends_on = [google_project_service.log_sink]
}

resource "google_logging_project_sink" "dns_query_logs" {
  name        = "dns-query-logs"
  destination = "pubsub.googleapis.com/${google_pubsub_topic.dns_query_logs.id}"

  # Resolvers may randomize the case of the query name.
  filter = "resource.type=\"dns_query\" AND jsonPayload.queryName=~\"(?i)(^|[.])${replace(var.domain_name, ".", "[.]")}[.]?$\""

  unique_writer_identity = true

  depends_on = [google_project_service.log_sink]
}

resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
  topic  = google_pubsub_topic.dns_query_logs.id
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.dns_query_logs.writer_identity
}
