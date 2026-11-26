data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_region" "use1" {
  provider = aws.use1
}

data "aws_route53_zone" "tsujiura" {
  name = local.domain_name
}

# lambroll owns the function, so it must be deployed before this can be read.
data "aws_lambda_function" "ingest_route53" {
  provider = aws.use1

  function_name = "tsujiura-ingest-route53"
}

data "aws_lambda_function" "frontend" {
  function_name = "tsujiura-frontend"
}

data "aws_lambda_function" "result_api" {
  function_name = "tsujiura-result-api"
}

data "google_service_account" "result_api" {
  account_id = "tsujiura-result-api"
}

data "google_dns_managed_zone" "tsujiura" {
  name = replace(local.domain_name, ".", "-")
}

data "google_compute_global_address" "frontend" {
  name = "tsujiura-frontend"
}
