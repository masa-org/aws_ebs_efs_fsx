#!/bin/bash

# EFS client
sudo apt-get update
sudo apt-get -y install git binutils
git clone https://github.com/aws/efs-utils
cd ./efs-utils
./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb


# FSx client
wget -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fsx-ubuntu-public-key.gpg >/dev/null
sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu bionic main" > /etc/apt/sources.list.d/fsxlustreclientrepo.list && apt-get update' 
sudo apt install -y lustre-client-modules-$(uname -r) 

# Create mount point 
sudo mkdir -p /fsx /efs

# Mount EFS
sudo mount -t efs -o tls ${efs_id}:/ /efs

# Mount FSx
sudo mount -t lustre -o relatime,flock ${fsx_dns_name}@tcp:/${fsx_mount_name} /fsx
