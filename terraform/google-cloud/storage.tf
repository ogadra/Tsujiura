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

resource "google_storage_bucket" "frontend" {
  # checkov:skip=CKV_GCP_62:Access logs are not used
  # checkov:skip=CKV_GCP_78:Terraform uploads every object again from web/
  name                        = format("tsujiura-frontend-%s", data.google_project.current.project_id)
  location                    = data.google_client_config.current.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  website {
    main_page_suffix = "index.html"
  }

  labels = local.common_labels

  depends_on = [google_project_service.storage]
}

resource "google_storage_bucket_object" "index_html" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  bucket         = google_storage_bucket.frontend.name
  name           = "index.html"
  content_type   = "text/html; charset=utf-8"
  source         = "${path.module}/../../web/index.html"
  source_md5hash = filemd5("${path.module}/../../web/index.html")
}

resource "google_storage_bucket_object" "provider_svg" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  bucket         = google_storage_bucket.frontend.name
  name           = "provider.svg"
  content_type   = "image/svg+xml"
  source         = "${path.module}/../../web/provider/google-cloud.svg"
  source_md5hash = filemd5("${path.module}/../../web/provider/google-cloud.svg")
}
