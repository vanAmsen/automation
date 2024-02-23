#!/bin/bash

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install Ansible
sudo apt install ansible -y

# Clone your Ansible playbook repository
git clone https://github.com/yourusername/your-private-repo.git
cd your-private-repo

# Run the Ansible playbook
ansible-playbook -i 'localhost,' docker_memos_install.yml -c local
