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

resource "google_service_account" "result_api" {
  account_id   = "tsujiura-result-api"
  display_name = "Tsujiura result API function"
}

resource "google_project_iam_custom_role" "result_api" {
  role_id = "tsujiuraResultApi"
  title   = "Tsujiura result API"

  permissions = ["datastore.entities.get"]
}

resource "google_project_iam_member" "result_api_firestore" {
  project = data.google_project.current.project_id
  role    = google_project_iam_custom_role.result_api.id
  member  = google_service_account.result_api.member
}

resource "google_storage_bucket_iam_member" "frontend_public" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.legacyObjectReader"
  member = "allUsers"
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "sts" {
  service            = "sts.googleapis.com"
  disable_on_destroy = true
}

resource "google_iam_workload_identity_pool" "result_api_aws" {
  workload_identity_pool_id = "tsujiura-aws"

  depends_on = [google_project_service.iam, google_project_service.iamcredentials, google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "result_api_aws" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.result_api_aws.workload_identity_pool_id
  workload_identity_pool_provider_id = "result-api"
  attribute_condition                = "attribute.aws_role == \"${local.result_api_assumed_role_arn}\""

  aws {
    account_id = split(":", local.result_api_assumed_role_arn)[4]
  }
}

resource "google_service_account_iam_member" "result_api_aws" {
  service_account_id = google_service_account.result_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.result_api_aws.name}/attribute.aws_role/${local.result_api_assumed_role_arn}"
}
