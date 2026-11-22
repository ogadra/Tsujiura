resource "google_storage_bucket" "asn" {
  name     = format("tsujiura-asn-%s", data.google_project.current.project_id)
  location = "asia-northeast1"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
