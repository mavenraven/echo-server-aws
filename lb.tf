

resource "aws_lb" "lb" {
	name = "echo-server-lb"
	internal = false
	ip_address_type = "ipv4"
	load_balancer_type = "application"
	security_groups = [aws_security_group.allow_tls.id]
	subnets = [aws_subnet.subnet-private-1.id, aws_subnet.subnet-private-2.id]
}

resource "aws_lb_listener" "lb_listener" {
	load_balancer_arn = aws_lb.lb.arn
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
	vpc_id = aws_vpc.vpc.id
	target_type = "ip"
}

resource "aws_lb_target_group" "green" {
	protocol = "HTTP"
	port = 80
	vpc_id = aws_vpc.vpc.id
	target_type = "ip"
}
