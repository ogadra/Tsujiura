terraform {
  required_version = ">= 1.17"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# Route53 query logs can only be delivered to CloudWatch Logs in us-east-1.
provider "aws" {
  alias   = "use1"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}
