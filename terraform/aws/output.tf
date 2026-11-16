output "asn_bucket" {
  value = aws_s3_bucket.asn.bucket
}

output "ingest_route53_repository_url" {
  value = aws_ecr_repository.ingest_route53.repository_url
}
