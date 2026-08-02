resource "aws_codedeploy_app" "api_service" {
  name             = "${var.project_name}-api-service"
  compute_platform = "ECS"
}

# The alarm that actually triggers automatic rollback. This is the
# resource behind the "CloudWatch-triggered rollback" line in the
# resume bullet — be able to point to this exact block in interviews.
resource "aws_cloudwatch_metric_alarm" "high_5xx_rate" {
  alarm_name          = "${var.project_name}-high-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Triggers CodeDeploy rollback when the green target group returns too many 5xx responses"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.green.arn_suffix
  }
}

resource "aws_codedeploy_deployment_group" "api_service" {
  app_name               = aws_codedeploy_app.api_service.name
  deployment_group_name  = "${var.project_name}-api-service-dg"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.api_service.name
  }

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5 # keeps old task set briefly in case manual rollback is needed
    }
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.prod.arn]
      }
      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    alarms  = [aws_cloudwatch_metric_alarm.high_5xx_rate.alarm_name]
    enabled = true
  }
}
