# Data source to get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "node_app_sg" {
  name        = "node-app-service-sg"
  description = "Allow inbound traffic on port 3000 for node app service"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule for port 3000 from anywhere
  ingress {
    description = "Application Port"
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

  tags = {
    Name = "node-app-sg"
  }
}