resource "aws_ecr_repository" "ingest_route53" {
  provider = aws.use1

  name = "tsujiura-ingest-route53"
}
