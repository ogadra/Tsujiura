resource "aws_s3_bucket" "asn" {
  provider = aws.use1

  bucket_prefix = "tsujiura-asn-"
}
