terraform {
    backend "s3" {
        bucket         = "tf-st-bkt"
        key            = "terraform.tfstate"
        region         = "ap-south-1"
        #dynamodb_table = "patient-survival-prediction-lock-table"
        use_lockfile = true
      
    }
required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.93.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"
}
# Create a VPC
resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "patient_survival_prediction_vpc"
    }
}
# Create a Subnet
resource "aws_subnet" "subnet" {
    vpc_id            = aws_vpc.vpc.id
    cidr_block        = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "patient_survival_prediction_subnet"
    }
}
# Create another Subnet
resource "aws_subnet" "subnet2" {
    vpc_id            = aws_vpc.vpc.id
    cidr_block        = "10.0.1.0/28"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
    tags = {
        Name = "patient_survival_prediction_subnet2"
    }
}
# Create internet gateway
resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "patient_survival_prediction_internet_gateway"
    }
}
# Create a route table
resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.vpc.id
    route         {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.internet_gateway.id
    }
    
    tags = {
        Name = "patient_survival_prediction_route_table"
    }
}

# Create a route table association
resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.subnet.id
    route_table_id = aws_route_table.route_table.id
}
# Crete another route table association
resource "aws_route_table_association" "route_table_association2" {
    subnet_id      = aws_subnet.subnet2.id
    route_table_id = aws_route_table.route_table.id
}
# Create a security group
resource "aws_security_group" "security_group" {
    name        = "patient_survival_prediction_security_group"
    vpc_id      = aws_vpc.vpc.id
    description = "Allow SSH and HTTP inbound traffic"
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 7860
        to_port     = 7860
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
        Name = "patient_survival_prediction_security_group"
    }
}
# Create a AWS service role for ECS
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  tags = {
    Name = "patient_survival_prediction_ecs_task_execution_role"
  }
}
data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
# Attach the AmazonECSTaskExecutionRolePolicy policy to the role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# Attach AmazonEC2ContainerServiceRole  policy to the role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment2" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}
# Create ECR registy    
resource "aws_ecr_repository" "patient_survival_prediction" {
    name                 = "patient_survival_prediction"
    image_tag_mutability = "MUTABLE"
    force_delete = true

    image_scanning_configuration {
        scan_on_push = true
    }
  tags = {
    Name = "patient_survival_prediction"
  }
}
# Create A null resource to trigger the ECR image build
resource "null_resource" "build_ecr_image" {
  
    provisioner "local-exec" {
        command = "aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.patient_survival_prediction.repository_url}"
    }
    provisioner "local-exec" {
        command = "docker build -t ${aws_ecr_repository.patient_survival_prediction.repository_url}:latest ."
    }
    provisioner "local-exec" {
        command = "docker push ${aws_ecr_repository.patient_survival_prediction.repository_url}:latest"
    }
  depends_on = [aws_ecr_repository.patient_survival_prediction]
}
# Create ECS cluster
resource "aws_ecs_cluster" "patient_survival_prediction" {
  name = "patient_survival_prediction"
  tags = {
    Name = "patient_survival_prediction"
  }
}
# Create ECS task definition
resource "aws_ecs_task_definition" "patient_survival_prediction" {
  family                   = "patient_survival_prediction"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_execution_role.arn
  container_definitions   = jsonencode([
    {
      name      = "patient_survival_prediction"
      image     = "${aws_ecr_repository.patient_survival_prediction.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 7860
          hostPort      = 7860
          protocol      = "tcp"
        }
      ]
    }
  ])
    tags = {
    Name = "patient_survival_prediction"
  }
}

# Add task to the ECS cluster
resource "aws_ecs_service" "patient_survival_prediction" {
  name            = "patient_survival_prediction"
  cluster         = aws_ecs_cluster.patient_survival_prediction.id
  task_definition = aws_ecs_task_definition.patient_survival_prediction.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
    security_groups  = [aws_security_group.security_group.id]
    assign_public_ip = true
  }
  tags = {
    Name = "patient_survival_prediction"
  }
}

# Create ECS service
