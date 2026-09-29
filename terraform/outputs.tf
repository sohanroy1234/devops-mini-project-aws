output "app_url" {
  description = "Public URL of the deployed app"
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.app.name
}

output "jenkins_url" {
  description = "Jenkins UI (allow ~3-5 min after apply for the bootstrap to finish)"
  value       = var.create_jenkins ? "http://${aws_eip.jenkins[0].public_ip}:8080" : "Jenkins not created"
}

output "jenkins_instance_id" {
  value = var.create_jenkins ? aws_instance.jenkins[0].id : ""
}

output "jenkins_admin_password_command" {
  description = "Run this to read the first-login Jenkins password (uses SSM, no SSH key)"
  value = var.create_jenkins ? join(" ", [
    "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.jenkins[0].id}",
    "# then inside the session run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
  ]) : ""
}

output "app_desired_count" {
  description = "Task count Jenkins should scale the service to (mirrors Jenkinsfile DESIRED_COUNT)"
  value       = var.app_desired_count
}
