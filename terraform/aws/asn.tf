resource "aws_s3_bucket" "asn" {
  provider = aws.use1

  bucket           = format("tsujiura-asn-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.use1.region)
  bucket_namespace = "account-regional"
}
