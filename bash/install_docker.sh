#!/bin/bash

# chmod +x install_docker.sh

# Updating system packages
sudo apt update
# Uncomment the next line if you want to upgrade all system packages
# sudo apt upgrade -y

# Install Docker prerequisites
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y

# Add Docker's official GPG key
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Setup stable repository for Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the apt package index
sudo apt-get update

# Install Docker Engine, CLI, Containerd, and Compose Plugin
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# Verify that Docker Engine is installed correctly
sudo docker run hello-world

# Additional step to manage Docker as a non-root user (Optional)
# sudo groupadd docker
# sudo usermod -aG docker $USER
# newgrp docker

echo "Docker and Docker Compose installation is complete."
