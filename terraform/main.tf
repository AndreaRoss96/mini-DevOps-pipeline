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
}

############################
# SECURITY GROUPS
############################

resource "aws_security_group" "node_app_sg" {
  name        = "node-app-sg"
  description = "SG for Node App"
  vpc_id      = "vpc-066085ae36844f7b6"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "SG for ALB"
  vpc_id      = "vpc-066085ae36844f7b6"

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

resource "aws_security_group" "grafana_sg" {
  name        = "grafana-ecs-sg"
  description = "SG for Grafana ECS"
  vpc_id      = "vpc-066085ae36844f7b6"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "grafana_ingress_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.grafana_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

############################
# ECR REPOSITORY
############################

resource "aws_ecr_repository" "app_repo" {
  name = "ecr-devops-pipeline"
}

############################
# ECS CLUSTER
############################

resource "aws_ecs_cluster" "cluster" {
  name = "node-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

############################
# LOAD BALANCER & TARGET GROUP
############################

resource "aws_lb" "alb" {
  name               = "main-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = ["subnet-04c85bb40bad4540b", "subnet-0a0a9410629a720d0"] # REPLACE with real subnets
}

resource "aws_lb_target_group" "grafana_tg" {
  name     = "grafana-tg"
  port     = 3000
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = "vpc-066085ae36844f7b6"
}

resource "aws_lb_listener" "grafana_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
  
  depends_on = [
    aws_lb_target_group.grafana_tg
  ]
}

############################
# ECS TASK DEFINITIONS
############################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = "grafana/grafana:latest"
      portMappings = [
        { containerPort = 3000, hostPort = 3000 }
      ]
    }
  ])
}

############################
# ECS SERVICES
############################

resource "aws_ecs_service" "grafana_service" {
  name            = "grafana-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.grafana.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-04c85bb40bad4540b", "subnet-0a0a9410629a720d0"]
    security_groups = [aws_security_group.grafana_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana_tg.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [
    aws_ecs_cluster.cluster,
    aws_lb_listener.grafana_listener
  ]
}
