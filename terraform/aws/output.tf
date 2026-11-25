output "asn_bucket" {
  description = "Read by the update-asn recipe in justfile."
  value       = aws_s3_bucket.asn.bucket
}

output "ingest_route53_repository_url" {
  description = "Read by the _deploy-aws recipe in justfile."
  value       = aws_ecr_repository.ingest_route53.repository_url
}

output "result_api_repository_url" {
  description = "Read by the _deploy-aws recipe in justfile."
  value       = aws_ecr_repository.result_api.repository_url
}

output "frontend_repository_url" {
  description = "Read by the _deploy-aws recipe in justfile."
  value       = aws_ecr_repository.frontend.repository_url
}

output "google_cloud_result_api_role_arn" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = aws_iam_role.google_cloud_result_api.arn
}
