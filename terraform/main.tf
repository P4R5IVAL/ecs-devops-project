
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-2"
  profile = "ecs-project"
}


data "aws_subnet" "public_a" {
  id = "subnet-047c0fbaf64dd9fed"
}

data "aws_subnet" "public_b" {
  id = "subnet-0d2f4970dba9f4d70"
}


data "aws_security_group" "alb" {
  id = "sg-05040ad3cfbc38bf7"
}

data "aws_security_group" "ecs" {
  id = "sg-0a785427e6e90dceb"
}


resource "aws_ecs_cluster" "flask" {
  name = "flask-terraform-cluster"
}


resource "aws_ecs_task_definition" "flask" {
  family                   = "flask-terraform-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = "arn:aws:iam::138720667855:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      name      = "flask-container"
      image     = "138720667855.dkr.ecr.eu-west-2.amazonaws.com/flask-devops:v1"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}


resource "aws_lb_target_group" "flask" {
  name        = "flask-terraform-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.existing.id

  health_check {
    path     = "/health"
    protocol = "HTTP"
  }
}


resource "aws_lb" "flask" {
  name               = "flask-terraform-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    data.aws_security_group.alb.id
  ]

  subnets = [
    data.aws_subnet.public_a.id,
    data.aws_subnet.public_b.id
  ]
}


data "aws_vpc" "existing" {
  id = "vpc-056e695ca1948cf39"
}

data "aws_acm_certificate" "flask" {
  domain      = "labs.p4r5iv4l.link"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.flask.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.flask.arn
  port              = 443
  protocol          = "HTTPS"

  certificate_arn = data.aws_acm_certificate.flask.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask.arn
  }
}

resource "aws_ecs_service" "flask" {
  name            = "flask-terraform-service"
  cluster         = aws_ecs_cluster.flask.id
  task_definition = aws_ecs_task_definition.flask.arn
  launch_type     = "FARGATE"
  desired_count   = 0

  network_configuration {
    subnets = [
      data.aws_subnet.public_a.id,
      data.aws_subnet.public_b.id
    ]

    security_groups = [
      data.aws_security_group.ecs.id
    ]

    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask.arn
    container_name   = "flask-container"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_lb_listener.https]
}

data "aws_route53_zone" "existing" {
  name         = "p4r5iv4l.link."
  private_zone = false
}

resource "aws_route53_record" "labs" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "labs.p4r5iv4l.link"
  type    = "A"

  alias {
    name                   = aws_lb.flask.dns_name
    zone_id                = aws_lb.flask.zone_id
    evaluate_target_health = false
  }
}
