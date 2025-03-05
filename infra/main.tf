resource "aws_key_pair" "main" {
  key_name   = "lab-vm-key"
  public_key = var.public_key
}

resource "aws_security_group" "lab_sg" {
  name        = "lab-vm-sg"
  description = "Ports to be open for testing the app"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "lab_ec2" {
  count                  = 1
  ami                    = var.ec2_ami
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  # user_data              = file("install_docker.sh")
  root_block_device {
    volume_size = 100 # in GB
    volume_type = "gp3"
    encrypted   = false
  }
  tags = {
    Name = "${format("lab-vm-%d", count.index)}"
  }
}
