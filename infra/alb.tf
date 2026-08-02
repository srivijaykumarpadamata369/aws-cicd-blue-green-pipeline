resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # No deletion protection / no access logging bucket — kept off
  # deliberately for a portfolio project to avoid extra S3 cost.
  # In production these would both be on; worth stating explicitly
  # in an interview as a conscious trade-off, not an oversight.
  enable_deletion_protection = false
}

# Blue = currently live target group
resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-tg-blue"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }
}

# Green = new version CodeDeploy shifts traffic to during a deployment
resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-tg-green"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }
}

resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.id
  }

  # CodeDeploy takes over control of this listener's target group
  # during a deployment, so its own lifecycle changes are ignored here.
  lifecycle {
    ignore_changes = [default_action]
  }
}

# Test listener CodeDeploy uses to validate the green environment
# before shifting live production traffic to it.
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.id
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}
