resource "aws_vpc" "vpc" {
	cidr_block = "10.0.0.0/16"
	instance_tenancy = "default"
}

resource "aws_subnet" "subnet-2a" {
	vpc_id     = aws_vpc.vpc.id
	cidr_block = "10.0.2.0/24"
	availability_zone = "us-east-2a"
}

resource "aws_subnet" "subnet-2b" {
	vpc_id     = aws_vpc.vpc.id
	cidr_block = "10.0.3.0/24"
	availability_zone = "us-east-2b"
}

resource "aws_internet_gateway" "internet_gateway" {
	vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "allow_tls" {
	name        = "allow_tls"
	description = "Allow TLS inbound traffic and all outbound traffic"
	vpc_id      = aws_vpc.vpc.id

	tags = {
		Name = "allow_tls"
	}
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
	security_group_id = aws_security_group.allow_tls.id
	cidr_ipv4         = aws_vpc.vpc.cidr_block
	from_port         = 443
	ip_protocol       = "tcp"
	to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
	security_group_id = aws_security_group.allow_tls.id
	cidr_ipv4         = "0.0.0.0/0"
	ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_route_table" "route_table" {
	vpc_id = aws_vpc.vpc.id

	# Don't need to route between different endpoints in the VPC.
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.internet_gateway.id
	}

}