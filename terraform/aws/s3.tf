resource "aws_s3_bucket" "asn" {
  # checkov:skip=CKV_AWS_18:Access logs are not used
  # checkov:skip=CKV_AWS_21:update-asn uploads the ASN database again from MaxMind
  # checkov:skip=CKV_AWS_144:update-asn uploads the ASN database again from MaxMind, so replication is not needed
  # checkov:skip=CKV_AWS_145:AWS managed encryption is sufficient
  # checkov:skip=CKV2_AWS_6:New buckets block public access by default
  # checkov:skip=CKV2_AWS_61:The bucket holds one object that update-asn overwrites
  # checkov:skip=CKV2_AWS_62:Nothing reacts to uploads of the ASN database
  provider = aws.use1

  bucket           = format("tsujiura-asn-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.use1.region)
  bucket_namespace = "account-regional"

  tags = local.common_tags
}
