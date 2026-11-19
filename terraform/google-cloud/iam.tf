resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
  topic  = google_pubsub_topic.dns_query_logs.id
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.dns_query_logs.writer_identity
}

resource "google_service_account" "ingest_cloud_dns" {
  account_id   = "tsujiura-ingest-cloud-dns"
  display_name = "Tsujiura Cloud DNS ingest function"
}

# Every predefined Firestore role that writes also reads.
resource "google_project_iam_custom_role" "ingest_cloud_dns" {
  role_id = "tsujiuraIngestCloudDns"
  title   = "Tsujiura Cloud DNS ingest"

  # The function sets documents without a precondition, which needs both.
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

# Separate from the runtime account, which holds the access to Firestore and the ASN bucket.
resource "google_service_account" "ingest_cloud_dns_trigger" {
  account_id   = "tsujiura-ingest-dns-trigger"
  display_name = "Tsujiura Cloud DNS ingest trigger"
}

# gcloud owns the Cloud Run service, so the role is granted on the project.
resource "google_project_iam_member" "ingest_cloud_dns_trigger" {
  for_each = toset(["roles/eventarc.eventReceiver", "roles/run.invoker"])

  project = data.google_project.current.project_id
  role    = each.value
  member  = google_service_account.ingest_cloud_dns_trigger.member
}
