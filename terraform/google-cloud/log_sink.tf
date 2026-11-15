resource "google_project_service" "log_sink" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  for_each = toset(["logging.googleapis.com", "pubsub.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_pubsub_topic" "dns_query_logs" {
  # checkov:skip=CKV_GCP_83:Google managed encryption is sufficient for this use case
  name = "dns-query-logs"

  labels = local.common_labels

  depends_on = [google_project_service.log_sink]
}

resource "google_logging_project_sink" "dns_query_logs" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name        = "dns-query-logs"
  destination = "pubsub.googleapis.com/${google_pubsub_topic.dns_query_logs.id}"

  # Resolvers may randomize the case of the query name.
  filter = "resource.type=\"dns_query\" AND jsonPayload.queryName=~\"(?i)(^|[.])${replace(local.domain_name, ".", "[.]")}[.]?$\""

  unique_writer_identity = true

  depends_on = [google_project_service.log_sink]
}

resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  topic  = google_pubsub_topic.dns_query_logs.id
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.dns_query_logs.writer_identity
}
