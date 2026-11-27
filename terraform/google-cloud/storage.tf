resource "google_project_service" "storage" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  service            = "storage.googleapis.com"
  disable_on_destroy = true
}

resource "google_storage_bucket" "asn" {
  # checkov:skip=CKV_GCP_62:Access logs are not used
  # checkov:skip=CKV_GCP_78:update-asn uploads the ASN database again from MaxMind
  name     = format("tsujiura-asn-%s", data.google_project.current.project_id)
  location = data.google_client_config.current.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = local.common_labels
}
