provider "aws" {
  region = "ap-south-1"
  profile = "mytejas"
}


resource "aws_vpc" "t3vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "t3vpc"
  }
}


resource "aws_subnet" "t3public" {
  vpc_id     = aws_vpc.t3vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  depends_on = [aws_vpc.t3vpc]

  tags = {
    Name = "t3public"
  }
}


resource "aws_subnet" "t3private" {
  vpc_id     = aws_vpc.t3vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "false"
  depends_on = [aws_vpc.t3vpc]

  tags = {
    Name = "t3private"
  }
}


resource "aws_internet_gateway" "t3ig" {
  vpc_id = aws_vpc.t3vpc.id
  depends_on = [aws_vpc.t3vpc]

  tags = {
    Name = "t3ig"
  }
}


resource "aws_route_table" "t3table" {
  vpc_id = aws_vpc.t3vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.t3ig.id
  }
  depends_on = [aws_vpc.t3vpc]

  tags = {
    Name = "t3table"
  }
}


resource "aws_route_table_association" "t3associate" {
  subnet_id      = aws_subnet.t3public.id
  route_table_id = aws_route_table.t3table.id
  depends_on = [aws_subnet.t3public]
}


resource "aws_security_group" "t3sg" {
  name        = "t3sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.t3vpc.id

 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "ssh"
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

  depends_on = [aws_vpc.t3vpc]

  tags = {
    Name = "t3sg"
  }
}


resource "aws_instance" "t3wpos" {
  ami           = "ami-049cbce295a54b26b"
  instance_type = "t2.micro"
  key_name      = "mykey"
  subnet_id =  aws_subnet.t3public.id
  vpc_security_group_ids = [ "${aws_security_group.t3sg.id}"]
  
  tags = {
    Name = "t3wpos"
  }
}

output "wordpress_public_ip"{
  value=aws_instance.t3wpos.public_ip
}


resource "aws_security_group" "t3mysqlsg" {
  name        = "basic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.t3vpc.id

  ingress {
    description = "t3mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.t3vpc]

  tags = {
    Name = "t3mysqlsg"
  }
}


resource "aws_instance" "t3mysqlos" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = "mykey"
  subnet_id =  aws_subnet.t3private.id
  vpc_security_group_ids = [aws_security_group.t3mysqlsg.id]
  
  tags = {
    Name = "t3mysqlos"
  }
}

resource "null_resource" "null" {
depends_on = [aws_instance.t3wpos,aws_instance.t3mysqlos]

connection {
        type        = "ssh"
    	user        = "ec2-user"
    	private_key = file("C:/Users/HP/Downloads/mykey.pem")
        host     = aws_instance.t3wpos.public_ip
        }

provisioner "local-exec" {    
      command = "start chrome http://${aws_instance.t3wpos.public_ip}/wordpress"
   }
}