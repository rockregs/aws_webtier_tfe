provider "aws" {
  # Configuration options
  region     = "us-east-1"
  access_key = "AKIAZH7UQ7TLJFWXN6S4"
  secret_key = "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"
}


variable "subnet_perfix" {
  description = "CIDR block for subnet"
}

#resource "<provider>_<resource_type>" "name" {
#  config option
#  key = "value"
#  ...
#}

# Create vpc
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "development"
  }
}

# Create IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "Public-Subnet"
  }
}

# Create custom route table
resource "aws_route_table" "dev_RT" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # all traffic allowed from internet
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Dev-Route-Table"
  }
}

# Create Subnet
resource "aws_subnet" "dev_subnet1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.subnet_perfix[0].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    #Name = "Dev-Subnet"
    Name = var.subnet_perfix[0].name
  }
}

# Create Subnet
resource "aws_subnet" "Prod_subnet1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.subnet_perfix[1].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    #Name = "Production-Subnet"
    Name = var.subnet_perfix[1].name
  }
}

# Asscoiate subnet with RT
resource "aws_route_table_association" "asc" {
  subnet_id      = aws_subnet.dev_subnet1.id
  route_table_id = aws_route_table.dev_RT.id
}

# Create Security Groups
resource "aws_security_group" "allow_web" {
  name        = "Allow Web Traffic"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow Web Traffic"
  }
}

#resource "aws_vpc" "prod_vpc" {
#  cidr_block       = "10.3.0.0/16"
#  tags = {
#    Name = "Production"
#  }
#}

#resource "aws_subnet" "prod_subnet1" {
#  vpc_id     = aws_vpc.dev_vpc.id
#  cidr_block = "10.3.2.0/24"
#  tags = {
#    Name = "Prod-Subnet"
#  }
#}

# Create network interface with an ip in subnet
resource "aws_network_interface" "dev_nic" {
  subnet_id       = aws_subnet.dev_subnet1.id
  private_ips     = ["10.0.10.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign elastic ip for public internet 

resource "aws_eip" "dev_pubip" {
  network_interface         = aws_network_interface.dev_nic.id
  associate_with_private_ip = "10.0.10.50"
  vpc                       = true
  depends_on = [
    aws_internet_gateway.gw
  ]
}

resource "aws_instance" "dev_webserver" {
  ami               = "ami-0641db4da1d840326"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "blissprduae"

  network_interface {
    network_interface_id = aws_network_interface.dev_nic.id
    device_index         = 0
  }

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo web server dev > /var/www/html/index.html'
            EOF
  tags = {
    Name = "Dev-Web-Server"
  }
}

output "public_ip" {
  value = aws_eip.dev_pubip.id
}



