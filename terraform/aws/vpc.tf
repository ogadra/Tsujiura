resource "aws_vpc" "tsujiura" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tsujiura"
  }
}

resource "aws_internet_gateway" "tsujiura" {
  vpc_id = aws_vpc.tsujiura.id

  tags = {
    Name = "tsujiura"
  }
}

resource "aws_subnet" "tsujiura_public" {
  for_each = local.public_subnet_cidrs

  vpc_id            = aws_vpc.tsujiura.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "tsujiura-public-${each.key}"
  }
}

resource "aws_route_table" "tsujiura_public" {
  vpc_id = aws_vpc.tsujiura.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tsujiura.id
  }

  tags = {
    Name = "tsujiura-public"
  }
}

resource "aws_route_table_association" "tsujiura_public" {
  for_each = aws_subnet.tsujiura_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.tsujiura_public.id
}

resource "aws_security_group" "tsujiura_alb" {
  name        = "tsujiura-alb"
  description = "HTTPS from the internet to the ALB"
  vpc_id      = aws_vpc.tsujiura.id
}

resource "aws_vpc_security_group_ingress_rule" "tsujiura_alb_https" {
  security_group_id = aws_security_group.tsujiura_alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
