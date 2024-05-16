#!/bin/bash

# Ensure curl is installed
if ! command -v curl &> /dev/null; then
    echo "curl could not be found, installing curl..."
    sudo apt update && sudo apt install curl -y
fi

# PowerDNS configuration variables
pdns_config_path="/etc/powerdns/pdns.conf"
api_key=$(openssl rand -hex 16) # Generate a secure random API key
webserver_port="8081"
pdns_version=$(pdns_control version) # Dynamically retrieve PowerDNS version
api_url="http://127.0.0.1:${webserver_port}/" # Use loopback address for API URL
local_net="192.168.12.0/22"

# Configure PowerDNS API settings
echo "Configuring PowerDNS API..."
sudo sed -i "s|^#* *api=.*|api=yes|" $pdns_config_path
sudo sed -i "s|^#* *api-key=.*|api-key=$api_key|" $pdns_config_path
sudo sed -i "s|^#* *webserver=.*|webserver=yes|" $pdns_config_path
sudo sed -i "s|^#* *webserver-port=.*|webserver-port=$webserver_port|" $pdns_config_path
sudo sed -i "s|^#* *webserver-address=.*|webserver-address=0.0.0.0|" $pdns_config_path

# Configure allow-from, allow-axfr-ips, and allow-dnsupdate-from settings
sudo sed -i "s|^#* *allow-from=.*|allow-from=127.0.0.0/8,::1,$local_net|" $pdns_config_path
sudo sed -i "s|^#* *allow-axfr-ips=.*|allow-axfr-ips=127.0.0.0/8,::1,$local_net|" $pdns_config_path
sudo sed -i "s|^#* *allow-dnsupdate-from=.*|allow-dnsupdate-from=127.0.0.0/8,::1,$local_net|" $pdns_config_path

# Restart PowerDNS service
echo "Restarting PowerDNS service..."
sudo systemctl restart pdns

# Verify API is functioning
echo "Verifying PowerDNS API..."
response=$(curl -s -o /dev/null -w "%{http_code}" --header "X-Api-Key: $api_key" "${api_url}api/v1/servers/localhost")
if [ "$response" == "200" ]; then
    echo "API is functioning correctly."
else
    echo "API verification failed with HTTP status code: $response"
fi

# Output the configuration for the user
echo "PowerDNS API configuration completed."
echo "API URL: $api_url"
echo "API Key: $api_key"
echo "PowerDNS Version: $pdns_version"
