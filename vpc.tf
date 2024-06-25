resource "aws_vpc" "echo_server" {
	cidr_block = "10.0.0.0/16"
	instance_tenancy = "default"
}

resource "aws_subnet" "public-1" {
	vpc_id     = aws_vpc.echo_server.id
	cidr_block = "10.0.1.0/24"
	availability_zone = "us-east-2a"
}

# Needed to satisfy ALB being in 2 different AZs.
resource "aws_subnet" "public-2" {
	vpc_id     = aws_vpc.echo_server.id
	cidr_block = "10.0.2.0/24"
	availability_zone = "us-east-2b"
}

resource "aws_subnet" "subnet-private" {
	vpc_id     = aws_vpc.echo_server.id
	cidr_block = "10.0.3.0/24"
	availability_zone = "us-east-2a"
}

resource "aws_internet_gateway" "gateway" {
	vpc_id = aws_vpc.echo_server.id
}

resource "aws_nat_gateway" "ecr_access" {
	subnet_id = aws_subnet.public-1.id
	depends_on = [aws_internet_gateway.gateway]
	allocation_id = aws_eip.nat_gateway_ip.id
}

resource "aws_eip" "nat_gateway_ip" {}

resource "aws_security_group" "allow_http" {
	name        = "allow-http"
	description = "Allow HTTP inbound traffic and all outbound traffic"
	vpc_id      = aws_vpc.echo_server.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
	security_group_id = aws_security_group.allow_http.id
	cidr_ipv4         = "0.0.0.0/0"
	from_port         = 80
	ip_protocol       = "tcp"
	to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
	security_group_id = aws_security_group.allow_http.id
	cidr_ipv4         = "0.0.0.0/0"
	ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_route_table" "public_route_table" {
	vpc_id = aws_vpc.echo_server.id

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.gateway.id
	}
}

resource "aws_route_table_association" "public_1" {
	route_table_id = aws_route_table.public_route_table.id
	subnet_id = aws_subnet.public-1.id
}

resource "aws_route_table_association" "public_2" {
	route_table_id = aws_route_table.public_route_table.id
	subnet_id = aws_subnet.public-2.id
}

resource "aws_route_table" "nat_route_table" {
	vpc_id = aws_vpc.echo_server.id

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_nat_gateway.ecr_access.id
	}
}

resource "aws_route_table_association" "private" {
	route_table_id = aws_route_table.nat_route_table.id
	subnet_id = aws_subnet.subnet-private.id
}