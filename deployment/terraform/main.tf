terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "The AWS region to deploy resources"
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "honeypot_image" {
  description = "Docker image for the honeypot container"
  default     = "public.ecr.aws/r6u4x6s4/honeypot:v2-arm64-latest"
}

variable "original_image" {
  description = "Docker image for the original container"
  default     = "public.ecr.aws/r6u4x6s4/honeypot:v1-arm64-latest"
}

# VPC and Networking
resource "aws_vpc" "workshop" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "workshop-vpc"
  }
}

resource "aws_internet_gateway" "workshop" {
  vpc_id = aws_vpc.workshop.id

  tags = {
    Name = "workshop-igw"
  }
}

resource "aws_subnet" "workshop_public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.workshop.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "Workshop Public Subnet ${count.index + 1}"
  }
}

resource "aws_route_table" "workshop_public" {
  vpc_id = aws_vpc.workshop.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.workshop.id
  }

  tags = {
    Name = "Workshop Public Route Table"
  }
}

resource "aws_route_table_association" "workshop_public" {
  count          = length(aws_subnet.workshop_public)
  subnet_id      = aws_subnet.workshop_public[count.index].id
  route_table_id = aws_route_table.workshop_public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "workshop-alb-sg"
  description = "Security group for Workshop ALB"
  vpc_id      = aws_vpc.workshop.id

  ingress {
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
}

resource "aws_security_group" "honeypot_container" {
  name        = "honeypot-container-sg"
  description = "Security group for Honeypot container"
  vpc_id      = aws_vpc.workshop.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "original_container" {
  name        = "original-container-sg"
  description = "Security group for Original container"
  vpc_id      = aws_vpc.workshop.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

# Add this new IAM policy attachment for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_logs" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.ecs_execution_role.name
}

# ECS Task Definitions (place these after the IAM roles)
resource "aws_ecs_task_definition" "honeypot" {
  family                   = "honeypot-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "honeypot-container"
      image = var.honeypot_image
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/honeypot-task"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_task_definition" "original" {
  family                   = "original-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "original-container"
      image = var.original_image
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/original-task"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

# ECS Clusters
resource "aws_ecs_cluster" "original" {
  name = "original-cluster"
}

resource "aws_ecs_cluster" "honeypot" {
  name = "honeypot-cluster"
}

# ECS Services
resource "aws_ecs_service" "honeypot" {
  name            = "honeypot-service"
  cluster         = aws_ecs_cluster.honeypot.id
  task_definition = aws_ecs_task_definition.honeypot.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.workshop_public[*].id
    security_groups  = [aws_security_group.honeypot_container.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.honeypot.arn
    container_name   = "honeypot-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.honeypot, aws_iam_role_policy_attachment.ecs_execution_role_policy]
}

resource "aws_ecs_service" "original" {
  name            = "original-service"
  cluster         = aws_ecs_cluster.original.id
  task_definition = aws_ecs_task_definition.original.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.workshop_public[*].id
    security_groups  = [aws_security_group.original_container.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.original.arn
    container_name   = "original-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.original, aws_iam_role_policy_attachment.ecs_execution_role_policy]
}

# ALB for Honeypot
resource "aws_lb" "honeypot" {
  name               = "honeypot-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.workshop_public[*].id

  enable_deletion_protection = false
}

# ALB for Original
resource "aws_lb" "original" {
  name               = "original-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.workshop_public[*].id

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "honeypot" {
  name        = "honeypot-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.workshop.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "honeypot" {
  load_balancer_arn = aws_lb.honeypot.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.honeypot.arn
  }
}

resource "aws_lb_target_group" "original" {
  name        = "original-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.workshop.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "original" {
  load_balancer_arn = aws_lb.original.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.original.arn
  }
}

# Outputs
output "honeypot_alb_dns_name" {
  description = "DNS name of the Honeypot Application Load Balancer"
  value       = aws_lb.honeypot.dns_name
}

output "honeypot_alb_url" {
  description = "URL of the Honeypot Application Load Balancer"
  value       = "http://${aws_lb.honeypot.dns_name}"
}

output "original_alb_dns_name" {
  description = "DNS name of the Original Application Load Balancer"
  value       = aws_lb.original.dns_name
}

output "original_alb_url" {
  description = "URL of the Original Application Load Balancer"
  value       = "http://${aws_lb.original.dns_name}"
}

output "honeypot_target_group_arn" {
  description = "ARN of the Honeypot Target Group"
  value       = aws_lb_target_group.honeypot.arn
}

output "original_target_group_arn" {
  description = "ARN of the Original Target Group"
  value       = aws_lb_target_group.original.arn
}

output "honeypot_target_group_console_link" {
  description = "Link to the Honeypot Target Group in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#TargetGroup:targetGroupArn=${aws_lb_target_group.honeypot.arn}"
}

output "original_target_group_console_link" {
  description = "Link to the Original Target Group in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#TargetGroup:targetGroupArn=${aws_lb_target_group.original.arn}"
}

output "honeypot_alb_console_link" {
  description = "Link to the Honeypot ALB in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#LoadBalancers:search=${aws_lb.honeypot.name}"
}

output "original_alb_console_link" {
  description = "Link to the Original ALB in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#LoadBalancers:search=${aws_lb.original.name}"
}

output "original_cluster_name" {
  description = "Name of the Original ECS Cluster"
  value       = aws_ecs_cluster.original.name
}

output "honeypot_cluster_name" {
  description = "Name of the Honeypot ECS Cluster"
  value       = aws_ecs_cluster.honeypot.name
}

output "original_cluster_console_link" {
  description = "Link to the Original ECS Cluster in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ecs/home?region=${var.aws_region}#/clusters/${aws_ecs_cluster.original.name}"
}

output "honeypot_cluster_console_link" {
  description = "Link to the Honeypot ECS Cluster in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ecs/home?region=${var.aws_region}#/clusters/${aws_ecs_cluster.honeypot.name}"
}

# Add CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "honeypot" {
  name              = "/ecs/honeypot-task"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "original" {
  name              = "/ecs/original-task"
  retention_in_days = 30
}

# Add outputs for CloudWatch Log Groups
output "honeypot_log_group_name" {
  description = "Name of the Honeypot CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.honeypot.name
}

output "original_log_group_name" {
  description = "Name of the Original CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.original.name
}

output "honeypot_log_group_console_link" {
  description = "Link to the Honeypot CloudWatch Log Group in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${aws_cloudwatch_log_group.honeypot.name}"
}

output "original_log_group_console_link" {
  description = "Link to the Original CloudWatch Log Group in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${aws_cloudwatch_log_group.original.name}"
}

