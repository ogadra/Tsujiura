resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = true
}

resource "google_storage_bucket" "asn" {
  name     = format("tsujiura-asn-%s", data.google_project.current.project_id)
  location = data.google_client_config.current.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_storage_bucket" "frontend" {
  name                        = format("tsujiura-frontend-%s", data.google_project.current.project_id)
  location                    = data.google_client_config.current.region
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  website {
    main_page_suffix = "index.html"
  }

  depends_on = [google_project_service.storage]
}

resource "google_storage_bucket_object" "index_html" {
  bucket         = google_storage_bucket.frontend.name
  name           = "index.html"
  content_type   = "text/html; charset=utf-8"
  source         = "${path.module}/../../web/index.html"
  source_md5hash = filemd5("${path.module}/../../web/index.html")
}

resource "google_storage_bucket_object" "provider_svg" {
  bucket         = google_storage_bucket.frontend.name
  name           = "provider.svg"
  content_type   = "image/svg+xml"
  source         = "${path.module}/../../web/provider/google-cloud.svg"
  source_md5hash = filemd5("${path.module}/../../web/provider/google-cloud.svg")
}
