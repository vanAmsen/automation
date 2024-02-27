#!/bin/bash

# PowerDNS configuration variables
pdns_config_path="/etc/powerdns/pdns.conf"
api_key=$(openssl rand -hex 16) # Generate a secure random API key
webserver_port="8081"
pdns_version=$(pdns_control version) # Dynamically retrieve PowerDNS version
api_url="http://$(hostname -I | awk '{print $1}'):${webserver_port}/" # Use the first IP from the `hostname` command

# Configure PowerDNS API settings
echo "Configuring PowerDNS API..."
sudo sed -i "s/^#* *api=.*/api=yes/" $pdns_config_path
sudo sed -i "s/^#* *api-key=.*/api-key=$api_key/" $pdns_config_path
sudo sed -i "s/^#* *webserver=.*/webserver=yes/" $pdns_config_path
sudo sed -i "s/^#* *webserver-port=.*/webserver-port=$webserver_port/" $pdns_config_path

# Restart PowerDNS service
echo "Restarting PowerDNS service..."
sudo systemctl restart pdns

# Output the configuration for the user
echo "PowerDNS API configuration completed."
echo "API URL: $api_url"
echo "API Key: $api_key"
echo "PowerDNS Version: $pdns_version"
