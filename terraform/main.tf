provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "flask_repo" {
  name = var.app_name

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "assoc" {
  count          = 2
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "sg" {
  name   = "flask-aws-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_lb" "app_lb" {
  name               = "flask-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = aws_subnet.subnet[*].id
}

resource "aws_lb_target_group" "app_tg" {
  name     = "flask-app-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "flask-app-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${var.app_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "task_def" {
  family                   = "${var.app_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "flask-container"
    image     = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.app_name}:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name,
        awslogs-region        = var.aws_region,
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "ecs_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_def.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.subnet[*].id
    security_groups  = [aws_security_group.sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "flask-container"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.listener]
}

output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}
