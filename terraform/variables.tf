variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1" # Mumbai
}

variable "project_name" {
  description = "Name prefix for all resources (also the ECR repo / ECS names)"
  type        = string
  default     = "devops-mini-project"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "container_port" {
  type    = number
  default = 4500
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "app_desired_count" {
  description = "Number of tasks Jenkins scales the service to on deploy"
  type        = number
  default     = 2
}

variable "create_jenkins" {
  description = "Create an EC2 instance running Jenkins"
  type        = bool
  default     = true
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.small"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach Jenkins (8080) and SSH (22). Use YOUR_IP/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "jenkins_key_name" {
  description = "Optional EC2 key pair name for SSH. Leave empty to use SSM Session Manager only."
  type        = string
  default     = ""
}
