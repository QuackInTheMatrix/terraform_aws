terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16.2"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# resource "aws_instance" "instance_1" {
#   ami                  = "ami-06db4d78cb1d3bbf9"
#   instance_type        = "t3.micro"
#   security_groups      = [aws_security_group.instances.name]
#   iam_instance_profile = "EC2forS3DynamoDB"
#   key_name             = "key_access"
#   # user data is executed by root
#   user_data            = <<-EOF
#                             #!/bin/bash
#                             aws s3 cp s3://instance.initialization/Archive.tar.gz /home/admin
#                             tar -xvzf /home/admin/Archive.tar.gz -C /home/admin
#                             bash /home/admin/initialize.sh
#                             EOF
# }
#
# resource "aws_instance" "instance_2" {
#   ami                  = "ami-06db4d78cb1d3bbf9"
#   instance_type        = "t3.micro"
#   security_groups      = [aws_security_group.instances.name]
#   iam_instance_profile = "EC2forS3DynamoDB"
#   key_name             = "key_access"
#   user_data            = <<-EOF
#                             #!/bin/bash
#                             aws s3 cp s3://instance.initialization/Archive.tar.gz /home/admin
#                             tar -xvzf /home/admin/Archive.tar.gz -C /home/admin
#                             bash /home/admin/initialize.sh
#                             EOF
# }

data "aws_ami" "debian" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
  filter {
    name   = "image-id"
    values = ["ami-06db*"]
  }
}

resource "aws_launch_configuration" "launch_config" {
  name_prefix          = "launch-config-"
  image_id             = data.aws_ami.debian.id
  instance_type        = "t3.micro"
  iam_instance_profile = "EC2forS3DynamoDB"
  key_name             = "key_access"
  security_groups      = [aws_security_group.instances.name]
  user_data            = <<-EOF
                            #!/bin/bash
                            aws s3 cp s3://instance.initialization/Archive.tar.gz /home/admin
                            tar -xvzf /home/admin/Archive.tar.gz -C /home/admin
                            bash /home/admin/initialize.sh
                            EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ASGforInsances" {
  name                 = "ASGforInsances"
  launch_configuration = aws_launch_configuration.launch_config.name
  min_size             = 2
  max_size             = 2
  desired_capacity     = 2
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  health_check_type = "ELB"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "ASGlb" {
  autoscaling_group_name = aws_autoscaling_group.ASGforInsances.id
  alb_target_group_arn   = aws_lb_target_group.instances.arn
}


data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnet_ids" "default_subnet" {
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id
  # from/to oznacava port range(5000-5000) ne MAPPING
  from_port   = 5000
  to_port     = 5000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_instance_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.instances.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "instances" {
  name     = "example-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# resource "aws_lb_target_group_attachment" "instance_1" {
#   target_group_arn = aws_lb_target_group.instances.arn
#   target_id        = aws_instance.instance_1.id
#   port             = 5000
# }
#
# resource "aws_lb_target_group_attachment" "instance_2" {
#   target_group_arn = aws_lb_target_group.instances.arn
#   target_id        = aws_instance.instance_2.id
#   port             = 5000
# }

resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}


resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb" "load_balancer" {
  name               = "web-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default_subnet.ids
  security_groups    = [aws_security_group.alb.id]
}
