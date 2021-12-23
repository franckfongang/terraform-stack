resource "aws_vpc" "vpc1" {
  cidr_block = var.cidr_blocks[0]
  tags = {
    Name : "${var.env_prefix}-vpc1"
  }

}
resource "aws_subnet" "SubnetA" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = var.cidr_blocks[2]
  availability_zone = "us-west-2a"
  tags = {
    Name : "${var.env_prefix}-subnetA"
  }

}
resource "aws_subnet" "SubnetB" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = var.cidr_blocks[3]
  availability_zone = "us-west-2b"
  tags = {
    Name : "${var.env_prefix}-subnetB"

  }
}
resource "aws_subnet" "SubnetC" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = var.cidr_blocks[1]
  availability_zone = "us-west-2c"
  tags = {
    Name : "${var.env_prefix}-subnetC"
  }

}

resource "aws_route_table" "pubrout" {
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name : "${var.env_prefix}-pubrout"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "${var.env_prefix}-IGW"
  }

}
resource "aws_route_table_association" "a-rtb-subnetA" {
  subnet_id      = aws_subnet.SubnetA.id
  route_table_id = aws_route_table.pubrout.id

}
resource "aws_route_table_association" "a-rtb-subnetB" {
  subnet_id      = aws_subnet.SubnetB.id
  route_table_id = aws_route_table.pubrout.id

}
resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.SubnetB.id
  tags = {
    "Name" = "${var.env_prefix}-Nat_gateway"
  }
}


resource "aws_route_table" "Privrout" {
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "instance" {
  subnet_id      = aws_subnet.SubnetC.id
  route_table_id = aws_route_table.Privrout.id
}


resource "aws_security_group" "SecurityAB" {
  name   = "securityAB"
  vpc_id = aws_vpc.vpc1.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_blocks[0]]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "SecurityC" {
  name   = "securityC"
  vpc_id = aws_vpc.vpc1.id
  ingress {
    from_port   = 7500
    to_port     = 7600
    protocol    = "tcp"
    cidr_blocks = ["10.10.10.128/26", "10.10.10.192/26"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_blocks[0]]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
data "aws_ami" "amazom-linux-image" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }


}
resource "aws_eip" "elasticip1" {
  instance = aws_instance.webserver1.id


}


resource "aws_instance" "webserver1" {
  ami           = data.aws_ami.amazom-linux-image.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.SubnetA.id
  vpc_security_group_ids = [aws_security_group.SecurityAB.id]
  availability_zone      = "us-west-2a"

  tags = {
    Name = "${var.env_prefix}-webserver1"
  }
}
resource "aws_eip" "elasticip2" {
  instance = aws_instance.webserver1.id


}
resource "aws_instance" "webserver2" {
  ami           = data.aws_ami.amazom-linux-image.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.SubnetB.id
  vpc_security_group_ids = [aws_security_group.SecurityAB.id]
  availability_zone      = "us-west-2b"

  tags = {
    Name = "${var.env_prefix}-webserver2"
  }
}
resource "aws_instance" "internal-instance" {
  ami           = data.aws_ami.amazom-linux-image.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.SubnetC.id
  vpc_security_group_ids = [aws_security_group.SecurityC.id]
  availability_zone      = "us-west-2c"

  tags = {
    Name = "${var.env_prefix}-internal-instance"
  }
}

######### load balancer resource ################
resource "aws_elb" "external_elb" {
  name     = "web-elb"
  internal = false
  subnets  = [aws_subnet.SubnetA.id]
  # availability_zones = ["us-west-2a", "us-west-2b"]

  # access_logs {
  #   bucket        = "elb-access-logs-212021"
  #   bucket_prefix = "elb-logs"
  #   interval      = 60
  # }

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # listener {
  #   instance_port      = 8001
  #   instance_protocol  = "https"
  #   lb_port            = 443
  #   lb_protocol        = "https"
  #   # ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  # }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/var/www/html/health/status.html" #make it as a variable 
    interval            = 30
  }

  instances                   = [aws_instance.webserver1.id, aws_instance.webserver2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "elb-tag"
  }
}

#######s3 bucket ########
resource "aws_s3_bucket" "elb_log_bucket" {
  bucket = "elb-access-logs-212021"
  acl    = "private"

  tags = {
    Name        = "My bucket"
    Environment = "test-log"
  }
}
