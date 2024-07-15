resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  tags                 = local.tags
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_default_security_group" "default" {
  vpc_id  = aws_vpc.main.id
  tags    = local.tags
  ingress = []
  egress  = []
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

data "aws_availability_zones" "main" {}

resource "aws_subnet" "main" {
  count                   = var.nb_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr, var.cidr_newbits, count.index)
  availability_zone       = data.aws_availability_zones.main.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { "Name" = "${local.name}-az${count.index}" })
  depends_on              = [aws_internet_gateway.main]
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "main" {
  count          = var.nb_subnets
  subnet_id      = element(aws_subnet.main.*.id, count.index)
  route_table_id = aws_route_table.main.id
}
