# ALB security group — only this SG can reach the internet on 80/443
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ECS container instance security group — least privilege: only
# accepts traffic from the ALB, not directly from the internet.
resource "aws_security_group" "ecs_instance" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow inbound only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB only"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH intentionally omitted. Use AWS Systems Manager Session Manager
  # for shell access instead — no open port 22, no key management,
  # and it's fully IAM-audited. Mention this explicitly in interviews;
  # it's a genuine least-privilege / no-open-SSH design decision.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-sg" }
}
