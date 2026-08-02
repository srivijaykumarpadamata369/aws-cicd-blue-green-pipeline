resource "aws_ecs_task_definition" "api_service" {
  family                   = "${var.project_name}-api-service"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge" # bridge mode works cleanly with a single EC2 instance
  cpu                      = "256"
  memory                   = "256" # small footprint fits comfortably on a t3.micro (1GB RAM)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-service"
      # Placeholder image — CI/CD replaces this tag on every deploy.
      # Terraform manages the infra; the pipeline manages the image.
      image     = "${aws_ecr_repository.api_service.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = 0 # dynamic host port — required for blue/green on EC2
        protocol      = "tcp"
      }]
      environment = [
        { name = "APP_VERSION", value = "1.0.0" },
        { name = "PORT", value = tostring(var.container_port) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  lifecycle {
    # CodeDeploy registers new task def revisions during deployments;
    # Terraform shouldn't fight it for ownership after initial creation.
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "api_service" {
  name            = "${var.project_name}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_service.arn
  desired_count   = 1 # single task fits free-tier instance; bump for real HA

  deployment_controller {
    type = "CODE_DEPLOY" # hands blue/green traffic shifting to CodeDeploy, not ECS's own rolling update
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "api-service"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.prod, aws_lb_listener.test]

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}
