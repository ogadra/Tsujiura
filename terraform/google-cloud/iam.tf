resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
  topic  = google_pubsub_topic.dns_query_logs.id
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.dns_query_logs.writer_identity
}

resource "google_service_account" "ingest_cloud_dns" {
  account_id   = "tsujiura-ingest-cloud-dns"
  display_name = "Tsujiura Cloud DNS ingest function"
}

resource "google_project_iam_custom_role" "ingest_cloud_dns" {
  role_id = "tsujiuraIngestCloudDns"
  title   = "Tsujiura Cloud DNS ingest"

  permissions = ["datastore.entities.create", "datastore.entities.update"]
}

resource "google_project_iam_member" "ingest_cloud_dns_firestore" {
  project = data.google_project.current.project_id
  role    = google_project_iam_custom_role.ingest_cloud_dns.id
  member  = google_service_account.ingest_cloud_dns.member
}

resource "google_storage_bucket_iam_member" "ingest_cloud_dns_asn" {
  bucket = google_storage_bucket.asn.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ingest_cloud_dns.member
}

resource "google_service_account" "ingest_cloud_dns_trigger" {
  account_id   = "tsujiura-ingest-dns-trigger"
  display_name = "Tsujiura Cloud DNS ingest trigger"
}

resource "google_project_iam_member" "ingest_cloud_dns_trigger_event_receiver" {
  project = data.google_project.current.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = google_service_account.ingest_cloud_dns_trigger.member
}

resource "google_project_iam_member" "ingest_cloud_dns_trigger_invoker" {
  project = data.google_project.current.project_id
  role    = "roles/run.invoker"
  member  = google_service_account.ingest_cloud_dns_trigger.member
}
