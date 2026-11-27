output "asn_bucket" {
  description = "Read by the update-asn recipe in justfile."
  value       = aws_s3_bucket.asn.bucket
}

output "ingest_route53_repository_url" {
  description = "Read by the _push-aws recipe in justfile."
  value       = aws_ecr_repository.ingest_route53.repository_url
}

output "result_api_repository_url" {
  description = "Read by the _push-aws recipe in justfile."
  value       = aws_ecr_repository.result_api.repository_url
}

output "frontend_repository_url" {
  description = "Read by the _push-aws recipe in justfile."
  value       = aws_ecr_repository.frontend.repository_url
}

output "google_cloud_result_api_role_arn" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = aws_iam_role.google_cloud_result_api.arn
}

output "results_table_name" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = aws_dynamodb_table.results.name
}

output "results_table_region" {
  description = "Read by the _deploy-google-cloud recipe in justfile."
  value       = data.aws_region.current.region
}

output "route53_delegation_set_id" {
  description = "Read by terraform/dns-route53 through terraform_remote_state."
  value       = aws_route53_delegation_set.tsujiura.id
}

output "route53_name_servers" {
  description = "Read by terraform/dns-route53 and terraform/dns-cloud-dns through terraform_remote_state."
  value       = local.route53_name_servers
}

output "route53_health_check_ids" {
  description = "Read by terraform/dns-route53 through terraform_remote_state."
  value       = { for key, health_check in aws_route53_health_check.tsujiura_frontend : key => health_check.id }
}

output "cloud_dns_health_check_id" {
  description = "Read by terraform/dns-cloud-dns through terraform_remote_state."
  value       = google_compute_health_check.tsujiura_frontend.id
}

output "frontend_ips" {
  description = "Read by terraform/dns-route53 and terraform/dns-cloud-dns through terraform_remote_state."
  value       = local.frontend_ips
}

output "acm_validation_record" {
  description = "Read by terraform/dns-route53 and terraform/dns-cloud-dns through terraform_remote_state."
  value       = local.acm_validation_record
}

output "route53_query_log_group_arn" {
  description = "Read by terraform/dns-route53 through terraform_remote_state."
  value       = aws_cloudwatch_log_group.route53_query_log.arn
}
