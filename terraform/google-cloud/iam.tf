resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  topic  = google_pubsub_topic.dns_query_logs.id
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.dns_query_logs.writer_identity
}

resource "google_service_account" "ingest_cloud_dns" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  account_id   = "tsujiura-ingest-cloud-dns"
  display_name = "Tsujiura Cloud DNS ingest function"
}

resource "google_project_iam_custom_role" "ingest_cloud_dns" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  role_id = "tsujiuraIngestCloudDns"
  title   = "Tsujiura Cloud DNS ingest"

  permissions = ["datastore.entities.create", "datastore.entities.update"]
}

resource "google_project_iam_member" "ingest_cloud_dns_firestore" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = google_project_iam_custom_role.ingest_cloud_dns.id
  member  = google_service_account.ingest_cloud_dns.member
}

resource "google_storage_bucket_iam_member" "ingest_cloud_dns_asn" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  bucket = google_storage_bucket.asn.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ingest_cloud_dns.member
}

resource "google_service_account" "ingest_cloud_dns_trigger" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  account_id   = "tsujiura-ingest-dns-trigger"
  display_name = "Tsujiura Cloud DNS ingest trigger"
}

resource "google_project_iam_member" "ingest_cloud_dns_trigger_event_receiver" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = google_service_account.ingest_cloud_dns_trigger.member
}

resource "google_project_iam_member" "ingest_cloud_dns_trigger_invoker" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = "roles/run.invoker"
  member  = google_service_account.ingest_cloud_dns_trigger.member
}

resource "google_service_account" "result_api" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  account_id   = "tsujiura-result-api"
  display_name = "Tsujiura result API function"
}

resource "google_project_iam_custom_role" "result_api" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  role_id = "tsujiuraResultApi"
  title   = "Tsujiura result API"

  permissions = ["datastore.entities.get"]
}

resource "google_project_iam_member" "result_api_firestore" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = google_project_iam_custom_role.result_api.id
  member  = google_service_account.result_api.member
}

resource "google_service_account" "frontend" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  account_id   = "tsujiura-frontend"
  display_name = "Tsujiura frontend function"
}

resource "google_service_account" "build" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  account_id   = "tsujiura-build"
  display_name = "Tsujiura function build"
}

resource "google_project_iam_member" "build_logs" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.build.member
}

resource "google_project_iam_member" "build_artifacts" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = "roles/artifactregistry.writer"
  member  = google_service_account.build.member
}

resource "google_project_iam_member" "build_sources" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  project = data.google_project.current.project_id
  role    = "roles/storage.objectViewer"
  member  = google_service_account.build.member

  condition {
    title      = "tsujiura-build-sources"
    expression = "resource.type == \"storage.googleapis.com/Object\" && (resource.name.startsWith(\"projects/_/buckets/gcf-v2-sources-\") || resource.name.startsWith(\"projects/_/buckets/gcf-v2-uploads-\") || resource.name.startsWith(\"projects/_/buckets/run-sources-\"))"
  }
}

resource "google_project_service" "iam" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "iam.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "iamcredentials" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "sts" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "sts.googleapis.com"
  disable_on_destroy = true
}

resource "google_iam_workload_identity_pool" "result_api_aws" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  workload_identity_pool_id = "tsujiura-aws"

  depends_on = [google_project_service.iam, google_project_service.iamcredentials, google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "result_api_aws" {
  # checkov:skip=CKV_GCP_125:This check only targets GitHub Actions OIDC and errors on providers without an oidc block
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  workload_identity_pool_id          = google_iam_workload_identity_pool.result_api_aws.workload_identity_pool_id
  workload_identity_pool_provider_id = "result-api"
  attribute_condition                = "attribute.aws_role == \"${local.result_api_assumed_role_arn}\""

  aws {
    account_id = split(":", local.result_api_assumed_role_arn)[4]
  }
}

resource "google_service_account_iam_member" "result_api_aws" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service_account_id = google_service_account.result_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.result_api_aws.name}/attribute.aws_role/${local.result_api_assumed_role_arn}"
}
