terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "satyajeet_alb_sg" {
  name        = "satyajeet_alb_sg"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_security_group" "satyajeet_ec2_sg" {
  name        = "satyajeet_ec2_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.satyajeet_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "satyajeet_ec2_1" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.satyajeet_ec2_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Satyajeet Load Balanced App - Server 1</h1>" > /var/www/html/index.html
EOF

  tags = {
    Name = "satyajeet-server-1"
  }
}

resource "aws_instance" "satyajeet_ec2_2" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.satyajeet_ec2_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[1]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Satyajeet Load Balanced App - Server 2</h1>" > /var/www/html/index.html
EOF

  tags = {
    Name = "satyajeet-server-2"
  }
}

resource "aws_lb" "satyajeet_alb" {
  name               = "satyajeet-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.satyajeet_alb_sg.id]
  subnets            = [data.aws_subnets.default.ids[0], data.aws_subnets.default.ids[1]]
}

resource "aws_lb_target_group" "satyajeet_tg" {
  name     = "satyajeet-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "satyajeet_listener" {
  load_balancer_arn = aws_lb.satyajeet_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.satyajeet_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "satyajeet_tg_attach_1" {
  target_group_arn = aws_lb_target_group.satyajeet_tg.arn
  target_id        = aws_instance.satyajeet_ec2_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "satyajeet_tg_attach_2" {
  target_group_arn = aws_lb_target_group.satyajeet_tg.arn
  target_id        = aws_instance.satyajeet_ec2_2.id
  port             = 80
}

output "satyajeet_alb_dns" {
  value = aws_lb.satyajeet_alb.dns_name
}
