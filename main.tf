variable "default_az" {
  default = "ca-central-1a"
}

provider "aws" {
  region     = "ca-central-1"
  access_key = "Put value here"
  secret_key = "Put value here"
}

//1 Create a VPC
resource "aws_vpc" "adeel-terrafom-vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    "type" = "big"
  }
}

//2 Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.adeel-terrafom-vpc.id
}

//3 Create Custom Route table
resource "aws_route_table" "adeel-rt" {
  vpc_id = aws_vpc.adeel-terrafom-vpc.id

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  } 

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.gw.id
  } 

  tags = {
    Name = "all-routes"
  }
}

//4 Create Subnet where webserver will reside with az
resource "aws_subnet" "adeel_pub_1" {
  vpc_id     =  aws_vpc.adeel-terrafom-vpc.id
  cidr_block = "10.1.1.0/24"
  availability_zone = var.default_az

  tags = {
    Name = "adeel-pub-subnet-1"
  }
}

//5. Route table association
resource "aws_route_table_association" "rt-pubsubnet-1" {
  subnet_id      = aws_subnet.adeel_pub_1.id
  route_table_id = aws_route_table.adeel-rt.id
}

//6. Create a security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id = aws_vpc.adeel-terrafom-vpc.id

  ingress {
    description      = "Allow all Http Traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // since its a webserver allow all the traffic
  }
  ingress {
    description      = "Allow all Https Traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // since its a webserver allow all the traffic
  }
  ingress {
    description      = "Allow all ssh Traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // since its a webserver allow all the traffic
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" // all the protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
//7. Create a network interface with an ip in the subnet that was created in step 4
// Elastic IP needs internet gateway to exist prior to its creation
// For this we use dependsOn
resource "aws_network_interface" "adeel-nic" {
  subnet_id      = aws_subnet.adeel_pub_1.id
  private_ips     = ["10.1.1.50"]   // pick any ip between the subnet
  security_groups = [aws_security_group.allow_web.id]

  //not attaching a device here
}
//8. Assign an Elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true

  network_interface = aws_network_interface.adeel-nic.id
  associate_with_private_ip = "10.1.1.50"

  depends_on = [
    aws_internet_gateway.gw
  ]
}

//9. Create Ubuntu and install/enable apache2
//Reason for assigning availability zone in AWS instance and subnet is 
// if we don't assign AWS will assign random AZ to both and then it 
// not work

resource "aws_instance" "adeel-webserver-ec2" {
  ami="ami-043e33039f1a50a56"
  instance_type = "t2.micro"
  key_name = "adeelKeys"
  availability_zone = var.default_az

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.adeel-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo adeel first web server > /var/www/html/index.html'
              EOF

  tags = {
    "Name" = "Adeel-web-Server"
  }
}