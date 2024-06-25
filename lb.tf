resource "aws_lb" "echo_server" {
	name = "echo-server-lb"
	internal = false
	ip_address_type = "ipv4"
	load_balancer_type = "application"
	security_groups = [aws_security_group.allow_http.id]
	subnets = [aws_subnet.public-1.id, aws_subnet.public-2.id]
}

resource "aws_lb_listener" "echo_server" {
	load_balancer_arn = aws_lb.echo_server.arn
	port = 80
	protocol = "HTTP"

	default_action {
		type = "forward"
		target_group_arn = aws_lb_target_group.blue.arn
	}
}

resource "aws_lb_target_group" "blue" {
	protocol = "HTTP"
	port = 80
	vpc_id = aws_vpc.echo_server.id
	target_type = "ip"
	deregistration_delay = "5"
}

resource "aws_lb_target_group" "green" {
	protocol = "HTTP"
	port = 80
	vpc_id = aws_vpc.echo_server.id
	target_type = "ip"
	deregistration_delay = "5"
}
