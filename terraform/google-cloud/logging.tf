resource "google_project_service" "logging" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "logging.googleapis.com"
  disable_on_destroy = true
}

resource "google_logging_project_sink" "dns_query_logs" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  name        = "dns-query-logs"
  destination = "pubsub.googleapis.com/${google_pubsub_topic.dns_query_logs.id}"

  # Resolvers may randomize the case of the query name.
  filter = "resource.type=\"dns_query\" AND jsonPayload.queryName=~\"(?i)(^|[.])${replace(local.domain_name, ".", "[.]")}[.]?$\""

  unique_writer_identity = true

  depends_on = [google_project_service.logging]
}
