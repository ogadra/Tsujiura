locals {
  public_subnet_cidrs = {
    "ap-northeast-1a" = "10.0.0.0/24"
    "ap-northeast-1c" = "10.0.1.0/24"
  }
}

resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:The VPC only holds the ALB
  cidr_block = "10.0.0.0/16"

  tags = merge(local.common_tags, {
    Name = "tsujiura"
  })
}

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "tsujiura-default"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "tsujiura"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.common_tags, {
    Name = "tsujiura-public-${each.key}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "tsujiura-public"
  })
}

resource "aws_route_table_association" "public" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
