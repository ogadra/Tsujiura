resource "google_project_service" "workload_identity" {
  for_each = toset(["iam.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "aws" {
  workload_identity_pool_id = "tsujiura-aws"

  depends_on = [google_project_service.workload_identity]
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws.workload_identity_pool_id
  workload_identity_pool_provider_id = "result-api"
  attribute_condition                = "attribute.aws_role == \"${var.result_api_assumed_role_arn}\""

  aws {
    account_id = split(":", var.result_api_assumed_role_arn)[4]
  }
}

resource "google_service_account_iam_member" "result_api_aws" {
  service_account_id = google_service_account.result_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aws.name}/attribute.aws_role/${var.result_api_assumed_role_arn}"
}

output "project_id" {
  value = var.project_id
}

output "result_api_workload_identity_audience" {
  value = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.aws.name}"
}
