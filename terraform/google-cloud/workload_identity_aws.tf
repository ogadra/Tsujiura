resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "sts" {
  service            = "sts.googleapis.com"
  disable_on_destroy = true
}

resource "google_iam_workload_identity_pool" "aws" {
  workload_identity_pool_id = "tsujiura-aws"

  depends_on = [google_project_service.iam, google_project_service.iamcredentials, google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws.workload_identity_pool_id
  workload_identity_pool_provider_id = "result-api"
  attribute_condition                = "attribute.aws_role == \"${local.result_api_assumed_role_arn}\""

  aws {
    account_id = split(":", local.result_api_assumed_role_arn)[4]
  }
}

resource "google_service_account_iam_member" "result_api_aws" {
  service_account_id = google_service_account.result_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aws.name}/attribute.aws_role/${local.result_api_assumed_role_arn}"
}

output "project_id" {
  value = data.google_project.current.project_id
}

output "result_api_workload_identity_audience" {
  value = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.aws.name}"
}
