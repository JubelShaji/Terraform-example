terraform {
  backend "s3" {
    bucket = "terraform-project-jubel"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}


variable "vpccidr" {
  default = "192.168.10.0/24"
}

data "aws_key_pair" "existing_key" {
  key_name = "jubel1"
}

resource "aws_vpc" "main" {
  cidr_block = var.vpccidr
  tags = {
    Name = "New_VPC"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.10.0/25"
  tags = {
    Name = "New_VPC_sub1"
  }
}

resource "aws_subnet" "main_subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.10.128/25"
  tags = {
    Name = "New_VPC_sub2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "New_VPC_igw"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "New_VPC_RT"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.main_subnet2.id
  route_table_id = aws_route_table.r.id
}

resource "aws_security_group" "websg" {
  name   = "web"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from VPC"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg"
  }
}

resource "aws_instance" "example" {
  ami           = "ami-00ca32bbc84273381"  
  instance_type = "t2.micro"
  key_name = data.aws_key_pair.existing_key.key_name   
  subnet_id     = aws_subnet.main_subnet2.id 
  vpc_security_group_ids = [aws_security_group.websg.id]    
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install httpd -y
              systemctl enable httpd
              systemctl start httpd
              EOF
  
  connection {
        type        = "ssh"
        user        = "ec2-user"
        private_key = file("C:/Users/Admin/Downloads/jubel1.pem")
        host        = self.public_ip
      }

  provisioner "file" {
        source      = "index.html"
        destination = "/home/ec2-user/index.html"
      }

  provisioner "remote-exec" {
    	inline = [
	    "sudo mkdir -p /var/www/html",
      	"sudo cp /home/ec2-user/index.html /var/www/html/index.html"
    	]
      }
  
  tags = {
    Name = "terra"
  }
}


output "instance_public_ip" {
  value = aws_instance.example.public_ip
}


