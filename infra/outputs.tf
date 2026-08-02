output "alb_dns_name" {
  description = "Public URL of the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_api_service_url" {
  value = aws_ecr_repository.api_service.repository_url
}

output "ecr_worker_service_url" {
  value = aws_ecr_repository.worker_service.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.api_service.name
}

output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.api_service.deployment_group_name
}

output "github_actions_role_arn" {
  description = "Put this in your GitHub repo as AWS_ROLE_ARN secret"
  value       = aws_iam_role.github_actions_role.arn
}
