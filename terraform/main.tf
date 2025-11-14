terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
  profile = "default"
}

# Create the ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name = "ecr-devops-pipeline"
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "node-app-cluster"

  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs_node_app" {
  name              = "/ecs/node-app"
  retention_in_days = 14
}

resource "aws_cloudwatch_dashboard" "ecs_dashboard" {
  dashboard_name = "ECS-Fargate-Monitoring"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        properties = {
          metrics = [
            [ "ECS/ContainerInsights", "CpuUtilized", "ClusterName", aws_ecs_cluster.app_cluster.name ],
            [ ".", "MemoryUtilized", ".", "." ]
          ],
          view   = "timeSeries",
          stacked = false,
          region = "eu-west-1",
          title  = "ECS Cluster CPU and Memory Usage"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU usage too high"
  dimensions = {
    ClusterName = aws_ecs_cluster.app_cluster.name
  }
}


# IAM Role for ECS Task Execution (for pulling ECR image)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Attach policy for Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "node-app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "node-app-container"
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group": aws_cloudwatch_log_group.ecs_node_app.name,
          "awslogs-region": "eu-west-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ])
}