resource "aws_ecr_repository" "ingest_route53" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  # checkov:skip=CKV_AWS_163:Scanning on push is not worth its cost for this project
  provider = aws.use1

  name = "tsujiura-ingest-route53"

  tags = local.common_tags
}

resource "aws_ecr_repository" "result_api" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  # checkov:skip=CKV_AWS_163:Scanning on push is not worth its cost for this project
  name = "tsujiura-result-api"

  tags = local.common_tags
}

resource "aws_ecr_repository" "frontend" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  # checkov:skip=CKV_AWS_163:Scanning on push is not worth its cost for this project
  name = "tsujiura-frontend"

  tags = local.common_tags
}
