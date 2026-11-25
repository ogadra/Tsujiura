resource "aws_ecr_repository" "ingest_route53" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  provider = aws.use1

  name = "tsujiura-ingest-route53"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "result_api" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  name = "tsujiura-result-api"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "frontend" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  name = "tsujiura-frontend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}
