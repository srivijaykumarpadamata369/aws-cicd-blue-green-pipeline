resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # gives real CloudWatch metrics for the observability story
  }
}

# ECS-optimized AMI, looked up dynamically so it's always current
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instance.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-ecs-instance" }
  }
}

# Single-instance ASG. Free tier covers 750 hrs/month of one t3.micro —
# exactly enough for one instance running continuously.
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "api_service" {
  name              = "/ecs/${var.project_name}/api-service"
  retention_in_days = 7 # short retention keeps CloudWatch Logs cost near zero
}
