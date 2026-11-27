output "asn_bucket" {
  description = "Read by the update-asn and _deploy-google-cloud recipes in justfile."
  value       = google_storage_bucket.asn.name
}

output "ingest_cloud_dns_service_account" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = google_service_account.ingest_cloud_dns.email
}

output "ingest_cloud_dns_trigger_service_account" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = google_service_account.ingest_cloud_dns_trigger.email
}

output "dns_query_logs_topic" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = google_pubsub_topic.dns_query_logs.name
}

output "result_api_service_account" {
  description = "Read by the _deploy-google-cloud and _deploy-aws recipes in justfile."
  value       = google_service_account.result_api.email
}

output "build_service_account" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = google_service_account.build.id
}

output "frontend_service_account" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = google_service_account.frontend.email
}

output "project_id" {
  description = "Read by the _deploy-aws recipe in justfile."
  value       = data.google_project.current.project_id
}

output "result_api_workload_identity_audience" {
  description = "Read by the _deploy-aws recipe in justfile."
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.result_api_aws.name}"
}

output "dns_authorization_record" {
  description = "Read by terraform/dns-route53 and terraform/dns-cloud-dns through terraform_remote_state."
  value = {
    name = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.frontend.dns_resource_record[0].data
  }
}
