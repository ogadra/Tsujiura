resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = true
}

resource "google_storage_bucket" "frontend" {
  name                        = "${data.google_project.current.project_id}-frontend"
  location                    = "asia-northeast1"
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  website {
    main_page_suffix = "index.html"
  }

  depends_on = [google_project_service.storage]
}

resource "google_storage_bucket_iam_member" "frontend_public" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.legacyObjectReader"
  member = "allUsers"
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

resource "google_compute_backend_bucket" "frontend" {
  name        = "tsujiura-frontend"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true

  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
  }

  depends_on = [google_project_service.compute]
}

resource "google_compute_url_map" "frontend" {
  name            = "tsujiura-frontend"
  default_service = google_compute_backend_bucket.frontend.id
}

resource "google_compute_global_address" "frontend" {
  name = "tsujiura-frontend"

  depends_on = [google_project_service.compute]
}
