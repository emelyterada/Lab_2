provider "aws" {Vpc_example
  region = "us-east-1" 
}

resource "Vpc" "Vpc_example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Vpc_example"
  }
}

resource "aws_internet_gateway" "example_igw" {
  vpc_id = Vpc.Vpc_example.id
  tags = {
    Name = "example_igw"
  }
}

resource "subnet" "example_subnet1" {
  vpc_id = Vpc.Vpc_example.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a" 
  tags = {
    Name = "example_subnet1"
  }
}

resource "subnet" "example_subnet2" {
  vpc_id = Vpc.Vpc_example.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b" 
  tags = {
    Name = "example_subnet2"
  }
}

resource "RouteTable" "ExampleRoute" {
  vpc_id = Vpc.Vpc_example.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }
  tags = {
    Name = "ExampleRoute"
  }
}

resource "RouteTable_association" "ExampleRoutea_1" {
  subnet_id = subnet.example_subnet1.id
  route_table_id = RouteTable.ExampleRoute.id
}

resource "RouteTable_association" "ExampleRoutea_2" {
  subnet_id = subnet.example_subnet2.id
  route_table_id = RouteTable.ExampleRoute.id
}

resource "aws_security_group" "example_sg" {
  name_prefix = "example_sg"
  description = "Allow inbound SSH and HTTP traffic"
  vpc_id = Vpc.Vpc_example.id

  ingress {
    from_port = 20
    to_port = 20
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 800
    to_port = 800
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example_ec2_instance_1" {
  ami = "hereAMI"  
  instance_type= "t2.micro" 
  key_name = "example_key_pair" 
  vpc_security_group_ids = [aws_security_group.example_sg.id]
  subnet_id = subnet.example_subnet1.id
  associate_public_ip_address = true
  user_data = <<-EOF
              
              sudo apt-get update
              sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose
              git clone https://github.com/prometheus/prometheus.git /home/ubuntu/prometheus
              cd /home/ubuntu/prometheus
              docker network create prometheus
              docker-compose -f examples/metrics/docker-compose.yml up -d
              docker run -d --name prometheus --network prometheus -p 9090:9090 -v /home/ubuntu/prometheus:/etc/prometheus prom/prometheus

            EOF
  tags = {
    Name = "example_ec2_instance_1"
  }
}
resource "null_resource" "install_prometheus" {
  depends_on = [aws_instance.example_ec2_instance_1]

  provisioner "remote-exec" {
    inline = [
      "sleep 60", 
      "curl localhost:9090",  
      "curl localhost:9100/metrics",  
      "curl localhost:8080/metrics",  
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.example_ec2_instance_1.public_ip
      private_key = file("example_key_pair.pem")  
    }
  }
}
resource "aws_instance" "example_ec2_instance_2" {
  ami = "hereAMI"
  instance_type = "t2.micro" 
  key_name = "example_key_pair" 
  vpc_security_group_ids = [aws_security_group.example_sg.id]
  subnet_id = subnet.example_subnet2.id
  associate_public_ip_address = true
  user_data = <<-EOF
              sudo apt-get update
              sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose
              git clone https://github.com/prometheus/node_exporter.git /home/ubuntu/node_exporter
              cd /home/ubuntu/node_exporter

              docker run -d --name node-exporter -p 9100:9100 -v "/proc:/host/proc" -v "/sys:/host/sys" -v "/:/rootfs" --net="host" prom/node-exporter
              git clone https://github.com/google/cadvisor.git /home/ubuntu/cadvisor
              cd /home/ubuntu/cadvisor

              docker run -d --name cadvisor-exporter -p 8080:8080 --volume=/var/run/docker.sock:/var/run/docker.sock google/cadvisor:latest -port=8080

              EOF
  tags = {
    Name = "example_ec2_instance_2"
  }
}
resource "null_resource" "install_node_exporter" {
  depends_on = [aws_instance.example_ec2_instance_2]

  provisioner "remote-exec" {
    inline = [
      "sleep 60",  
      "curl localhost:9100/metrics", 
      "curl localhost:8080/metrics", 
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.example_ec2_instance_2.public_ip
      private_key = file("example_key_pair.pem")  
    }
  }
}