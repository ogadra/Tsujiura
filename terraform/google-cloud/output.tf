output "asn_bucket" {
  description = "Read by the update-asn recipe in justfile."
  value       = google_storage_bucket.asn.name
}
