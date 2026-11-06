resource "google_project_service" "ingest_cloud_dns" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
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
  project = var.project_id
  role    = google_project_iam_custom_role.ingest_cloud_dns.id
  member  = google_service_account.ingest_cloud_dns.member
}

# Separate from the runtime account, which may only write to Firestore.
resource "google_service_account" "ingest_cloud_dns_trigger" {
  account_id   = "tsujiura-ingest-dns-trigger"
  display_name = "Tsujiura Cloud DNS ingest trigger"
}

# gcloud owns the Cloud Run service, so the role is granted on the project.
resource "google_project_iam_member" "ingest_cloud_dns_trigger" {
  for_each = toset(["roles/eventarc.eventReceiver", "roles/run.invoker"])

  project = var.project_id
  role    = each.value
  member  = google_service_account.ingest_cloud_dns_trigger.member
}

output "ingest_cloud_dns_service_account" {
  value = google_service_account.ingest_cloud_dns.email
}

output "ingest_cloud_dns_trigger_service_account" {
  value = google_service_account.ingest_cloud_dns_trigger.email
}

output "dns_query_logs_topic" {
  value = google_pubsub_topic.dns_query_logs.name
}
