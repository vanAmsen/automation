#!/bin/bash

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install Git
sudo apt install git -y

# Install Ansible
sudo apt install ansible -y

# Clone your Ansible playbook repository
git clone https://github.com/vanAmsen/automation.git
cd automation/ansible

# Run the Ansible playbook
ansible-playbook -i 'localhost,' docker_memos_install.yml -c local
