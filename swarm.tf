provider "aws" {
  region = "${var.region}"
}

resource "aws_instance" "manager" {
    ami = "ami-05bed57612cde7dce"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.swarm_sg.name}"]
    key_name = "${var.key_name}"

    connection {
        user = "ec2-user"
        private_key = "${file("./key-pair.pem")}"
    }
  
    tags = {
        Name = "Swarm Manager"
    }

    provisioner "local-exec" {
        # Keep in a local file the swarm manager IP address
        command = "echo Manager IP: ${self.public_ip} > manager_ip.txt"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo yum install -y docker",
            "sudo usermod -aG docker ec2-user",
            "docker swarm init --advertise-addr ${self.private_ip}",
            "docker swarm join-token worker --quiet > /home/ec2-user/worker-token.txt"
        ]
    }
}

resource "aws_instance" "worker" {
    count = 2
    ami = "ami-05bed57612cde7dce"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.swarm_sg.name}"]
    key_name = "${var.key_name}"

    connection {
        user = "ec2-user"
        private_key = "${file("./key-pair.pem")}"
    }
  
    tags = {
        Name = "Swarm Worker ${count.index} "
    }
    
    provisioner "file" {
        source = "key-pair.pem"
        destination = "/home/ec2-user/key.pem"
  }

    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo yum install -y docker",
            "sudo usermod -aG docker ec2-user",
            "sudo chmod 400 /home/ec2-user/key.pem",
            "sudo scp -o StrictHostKeyChecking=no -o NoHostAuthenticationForLocalhost=yes -o UserKnownHostsFile=/dev/null -i key.pem ec2-user@${aws_instance.manager.private_ip}:/home/ec2-user/worker-token.txt .",
            "docker swarm join --token $(cat /home/ec2-user/worker-token.txt) ${aws_instance.manager.private_ip}:2377"
        ]
    }

    depends_on = ["aws_instance.manager"]
}
