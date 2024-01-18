data "http" "ifconfig" {
  url = "https://ifconfig.co/ip"
}

locals {
  current_ip = "${chomp("${data.http.ifconfig.response_body}")}/32"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    #values = ["ubuntu/images/hvm-ssd/ubuntu-disco-19.04-amd64-server-*"]
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "random_id" "app-server-id" {
  prefix      = "${var.prefix}-hashicat-"
  byte_length = 8
}

######### VPC #################
data "aws_vpc" "my_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "public" {
  vpc_id = data.aws_vpc.my_vpc.id

  filter {
    name   = "tag:Name"
    values = ["masa-public"]
  }
}

###### Security groups #########

resource "aws_security_group" "sg" {
  name = "${var.prefix}-security-group"

  vpc_id = data.aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.current_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.current_ip]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.current_ip]
  }

  # EFS
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.public.cidr_block]
  }

  # FSx
  ingress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.public.cidr_block]
  }


  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

###### SSH keys #####################

locals {
  private_key_filename = "${var.prefix}-ssh-key"
}

resource "tls_private_key" "masa_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "masa_key_pair" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.masa_key.public_key_openssh
}

resource "local_sensitive_file" "foo" {
  content         = tls_private_key.masa_key.private_key_pem
  filename        = "${path.module}/${local.private_key_filename}.pem"
  file_permission = "0400"
}

######### EC2 ########################

resource "aws_instance" "instance1" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.masa_key_pair.key_name
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sg.id]

  tags = {
    Name = "${var.prefix}-instance1"
  }

  depends_on = [
    aws_efs_mount_target.efs-mt,
    aws_fsx_lustre_file_system.fsx 
  ]

  user_data = <<EOF
#!/bin/bash

# EFS client
sudo apt-get update
sudo apt-get -y install git binutils
git clone https://github.com/aws/efs-utils
cd ./efs-utils
./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb

sudo mkdir -p /efs
sudo mount -t efs -o tls ${aws_efs_file_system.efs.id}:/ /efs

# FSx client
wget -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fsx-ubuntu-public-key.gpg >/dev/null
sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu bionic main" > /etc/apt/sources.list.d/fsxlustreclientrepo.list && apt-get update'
sudo apt install -y lustre-client-modules-$(uname -r)

sudo mkdir -p /fsx
sudo mount -t lustre -o relatime,flock ${aws_fsx_lustre_file_system.fsx.dns_name}@tcp:/${aws_fsx_lustre_file_system.fsx.mount_name} /fsx
EOF

}

resource "aws_instance" "instance2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.masa_key_pair.key_name
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sg.id]

  tags = {
    Name = "${var.prefix}-instance2"
  }

  depends_on = [
    aws_efs_mount_target.efs-mt, 
    aws_fsx_lustre_file_system.fsx
  ]

  user_data = <<EOF
#!/bin/bash

# EFS client
sudo apt-get update
sudo apt-get -y install git binutils
git clone https://github.com/aws/efs-utils
cd ./efs-utils
./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb

sudo mkdir -p /efs
sudo mount -t efs -o tls ${aws_efs_file_system.efs.id}:/ /efs

# FSx client
wget -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fsx-ubuntu-public-key.gpg >/dev/null
sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu bionic main" > /etc/apt/sources.list.d/fsxlustreclientrepo.list && apt-get update'
sudo apt install -y lustre-client-modules-$(uname -r)

sudo mkdir -p /fsx
sudo mount -t lustre -o relatime,flock ${aws_fsx_lustre_file_system.fsx.dns_name}@tcp:/${aws_fsx_lustre_file_system.fsx.mount_name} /fsx
EOF

}


################ EBS ########################

resource "aws_ebs_volume" "example" {
  availability_zone = "${var.region}a"
  size              = 4
  type              = "io2"
  iops              = 100

  multi_attach_enabled = true

  tags = {
    Name = "${var.prefix}-ebs"
  }
}

resource "aws_volume_attachment" "ebs_att1" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.instance1.id
}

resource "aws_volume_attachment" "ebs_att2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.instance2.id
}

################ EFS ########################

resource "aws_efs_file_system" "efs" {
  creation_token = "my-product"
  encrypted      = true

  tags = {
    Name = "${var.prefix}-Demo"
  }
}

resource "aws_efs_mount_target" "efs-mt" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.aws_subnet.public.id
  security_groups = [aws_security_group.sg.id]
}

############# FSx ###########################

resource "aws_fsx_lustre_file_system" "fsx" {
  storage_capacity            = 1200
  deployment_type             = "PERSISTENT_1"
  storage_type                = "SSD"
  per_unit_storage_throughput = 50
  subnet_ids                  = [data.aws_subnet.public.id]
  security_group_ids          = [aws_security_group.sg.id]
}
