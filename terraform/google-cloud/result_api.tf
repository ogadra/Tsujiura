resource "google_service_account" "result_api" {
  account_id   = "tsujiura-result-api"
  display_name = "Tsujiura result API function"
}

# roles/datastore.viewer also lists documents and reads the database metadata.
resource "google_project_iam_custom_role" "result_api" {
  role_id = "tsujiuraResultApi"
  title   = "Tsujiura result API"

  permissions = ["datastore.entities.get"]
}

resource "google_project_iam_member" "result_api_firestore" {
  project = var.project_id
  role    = google_project_iam_custom_role.result_api.id
  member  = google_service_account.result_api.member
}

output "result_api_service_account" {
  value = google_service_account.result_api.email
}
