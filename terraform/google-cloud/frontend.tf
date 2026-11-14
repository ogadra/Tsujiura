resource "google_project_service" "frontend" {
  for_each = toset(["compute.googleapis.com", "storage.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "frontend" {
  name                        = "${data.google_project.current.project_id}-frontend"
  location                    = "asia-northeast1"
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  # The backend bucket answers / with this object.
  website {
    main_page_suffix = "index.html"
  }

  depends_on = [google_project_service.frontend]
}

# roles/storage.objectViewer also lets anyone list the bucket.
resource "google_storage_bucket_iam_member" "frontend_public" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.legacyObjectReader"
  member = "allUsers"
}

resource "google_storage_bucket_object" "frontend" {
  for_each = {
    "index.html" = { source = "index.html", content_type = "text/html; charset=utf-8" }
    "main.js"    = { source = "main.js", content_type = "text/javascript; charset=utf-8" }
    # Cloud DNS points the token names here, and the page reads this width to tell that Cloud DNS answered.
    "provider.svg" = { source = "provider/google-cloud.svg", content_type = "image/svg+xml" }
  }

  bucket         = google_storage_bucket.frontend.name
  name           = each.key
  content_type   = each.value.content_type
  source         = "${path.module}/../../web/${each.value.source}"
  source_md5hash = filemd5("${path.module}/../../web/${each.value.source}")
}

resource "google_compute_backend_bucket" "frontend" {
  name        = "tsujiura-frontend"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true

  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
  }

  depends_on = [google_project_service.frontend]
}

resource "google_compute_url_map" "frontend" {
  name            = "tsujiura-frontend"
  default_service = google_compute_backend_bucket.frontend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "frontend"
  }

  path_matcher {
    name            = "frontend"
    default_service = google_compute_backend_bucket.frontend.id

    path_rule {
      paths   = ["/api/result"]
      service = google_compute_backend_service.result_api.id
    }
  }
}

resource "google_compute_global_address" "frontend" {
  name = "tsujiura-frontend"

  depends_on = [google_project_service.frontend]
}
