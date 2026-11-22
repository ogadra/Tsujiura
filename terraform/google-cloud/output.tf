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
