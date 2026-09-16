
resource "aws_lb" "main" {
  name               = "marketly-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "k3s" {
  name     = "k3s-tg"
  port     = 30080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s.arn
  }
}

resource "aws_autoscaling_attachment" "workers" {
  autoscaling_group_name = var.asg_name
  lb_target_group_arn    = aws_lb_target_group.k3s.arn
}
