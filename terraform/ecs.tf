
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

# Service Creation
resource "aws_ecs_service" "node_app_service" {
  name            = "node-app-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.node_app_sg.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }

  tags = {
    Name = "node-app-service"
  }
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