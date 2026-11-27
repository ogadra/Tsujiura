resource "aws_vpc" "tsujiura" {
  # checkov:skip=CKV2_AWS_11:The VPC only holds the ALB
  cidr_block = "10.0.0.0/16"

  tags = merge(local.common_tags, {
    Name = "tsujiura"
  })
}

resource "aws_default_security_group" "tsujiura" {
  vpc_id = aws_vpc.tsujiura.id

  tags = merge(local.common_tags, {
    Name = "tsujiura-default"
  })
}

resource "aws_internet_gateway" "tsujiura" {
  vpc_id = aws_vpc.tsujiura.id

  tags = merge(local.common_tags, {
    Name = "tsujiura"
  })
}

resource "aws_subnet" "tsujiura_public" {
  for_each = local.public_subnet_cidrs

  vpc_id            = aws_vpc.tsujiura.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.common_tags, {
    Name = "tsujiura-public-${each.key}"
  })
}

resource "aws_route_table" "tsujiura_public" {
  vpc_id = aws_vpc.tsujiura.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tsujiura.id
  }

  tags = merge(local.common_tags, {
    Name = "tsujiura-public"
  })
}

resource "aws_route_table_association" "tsujiura_public" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  for_each = aws_subnet.tsujiura_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.tsujiura_public.id
}

resource "aws_security_group" "tsujiura_alb" {
  name        = "tsujiura-alb"
  description = "HTTPS from the internet to the ALB"
  vpc_id      = aws_vpc.tsujiura.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "tsujiura_alb_https" {
  security_group_id = aws_security_group.tsujiura_alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "tsujiura_alb_ecs" {
  for_each = local.ecs_container_ports

  security_group_id            = aws_security_group.tsujiura_alb.id
  description                  = "HTTP from the ALB to the ${each.key} container"
  referenced_security_group_id = aws_security_group.tsujiura_ecs.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"

  tags = local.common_tags
}

resource "aws_security_group" "tsujiura_ecs" {
  # checkov:skip=CKV2_AWS_5:ecspresso attaches the group to the ECS service
  name        = "tsujiura-ecs"
  description = "HTTP from the ALB to the ECS tasks"
  vpc_id      = aws_vpc.tsujiura.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "tsujiura_ecs_alb" {
  for_each = local.ecs_container_ports

  security_group_id            = aws_security_group.tsujiura_ecs.id
  description                  = "HTTP from the ALB to the ${each.key} container"
  referenced_security_group_id = aws_security_group.tsujiura_alb.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "tsujiura_ecs_https" {
  security_group_id = aws_security_group.tsujiura_ecs.id
  description       = "HTTPS from the ECS tasks to AWS and Google Cloud APIs"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = local.common_tags
}
