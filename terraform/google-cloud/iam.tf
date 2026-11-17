resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
  topic  = google_pubsub_topic.dns_query_logs.id
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.dns_query_logs.writer_identity
}
