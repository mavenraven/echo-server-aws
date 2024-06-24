resource "aws_vpc" "vpc" {
	cidr_block = "10.0.0.0/16"
	instance_tenancy = "default"
}

resource "aws_subnet" "subnet-public-1" {
	vpc_id     = aws_vpc.vpc.id
	cidr_block = "10.0.2.0/24"
	availability_zone = "us-east-2a"
}

# We use a different AZs to make the ALB logic happy about:
# "A load balancer cannot be attached to multiple subnets in the same Availability Zone"
# Note that we don't have HA because all tasks go to a single AZ.
resource "aws_subnet" "subnet-public-2" {
	vpc_id     = aws_vpc.vpc.id
	cidr_block = "10.0.5.0/24"
	availability_zone = "us-east-2b"
}

resource "aws_subnet" "subnet-private" {
	vpc_id     = aws_vpc.vpc.id
	cidr_block = "10.0.3.0/24"
	availability_zone = "us-east-2a"
}

resource "aws_internet_gateway" "internet_gateway" {
	vpc_id = aws_vpc.vpc.id
}

# Needed so Fargate can pull from the public ECR endpoint without assigning each task a public IP.
resource "aws_nat_gateway" "nat_gateway" {
	subnet_id = aws_subnet.subnet-public-1.id
	depends_on = [aws_internet_gateway.internet_gateway]
	allocation_id = aws_eip.nat_gateway_ip.id
}

resource "aws_eip" "nat_gateway_ip" {
}

resource "aws_security_group" "allow_tls" {
	name        = "allow_tls"
	description = "Allow TLS inbound traffic and all outbound traffic"
	vpc_id      = aws_vpc.vpc.id

	tags = {
		Name = "allow_tls"
	}
}

#TODO: get certs working or rename this security group
resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
	security_group_id = aws_security_group.allow_tls.id
	cidr_ipv4         = "0.0.0.0/0"
	from_port         = 80
	ip_protocol       = "tcp"
	to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
	security_group_id = aws_security_group.allow_tls.id
	cidr_ipv4         = "0.0.0.0/0"
	ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_route_table" "public_route_table" {
	vpc_id = aws_vpc.vpc.id

	# Don't need to route between different endpoints in the VPC.
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.internet_gateway.id
	}
}

resource "aws_route_table_association" "public_1_route_table_association" {
	route_table_id = aws_route_table.public_route_table.id
	subnet_id = aws_subnet.subnet-public-1.id
}

resource "aws_route_table_association" "public_2_route_table_association" {
	route_table_id = aws_route_table.public_route_table.id
	subnet_id = aws_subnet.subnet-public-2.id
}

resource "aws_route_table" "nat_route_table" {
	vpc_id = aws_vpc.vpc.id

	# Don't need to route between different endpoints in the VPC.
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_nat_gateway.nat_gateway.id
	}
}

resource "aws_route_table_association" "private_route_table_association" {
	route_table_id = aws_route_table.nat_route_table.id
	subnet_id = aws_subnet.subnet-private.id
}