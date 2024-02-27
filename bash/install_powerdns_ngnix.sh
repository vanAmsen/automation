#!/bin/bash

# Prompt for server name or IP
read -p "Enter the server name or IP address for PowerDNS Admin: " server_name

# Define necessary variables
powerdns_admin_path="/opt/web/powerdns-admin"
pdns_user="pdns"
pdns_group="pdns"
systemd_service_file="/etc/systemd/system/powerdns-admin.service"
systemd_socket_file="/etc/systemd/system/powerdns-admin.socket"
systemd_env_file="/etc/systemd/system/powerdns-admin.service.d/override.conf"
tmpfiles_config_file="/etc/tmpfiles.d/powerdns-admin.conf"
nginx_config_file="/etc/nginx/conf.d/powerdns-admin.conf"

# Install necessary packages
sudo apt-get update
sudo apt-get install -y nginx

# Create PowerDNS-Admin directories and set permissions
sudo mkdir -p $powerdns_admin_path
sudo chown -R $pdns_user:$pdns_group $powerdns_admin_path

# Create and set permissions for the run directory
sudo mkdir -p /run/powerdns-admin/
sudo chown $pdns_user:$pdns_group /run/powerdns-admin/

# Create systemd service file
sudo tee $systemd_service_file > /dev/null << EOF
[Unit]
Description=PowerDNS-Admin
Requires=powerdns-admin.socket
After=network.target

[Service]
PIDFile=/run/powerdns-admin/pid
User=$pdns_user
Group=$pdns_group
WorkingDirectory=$powerdns_admin_path
ExecStart=$powerdns_admin_path/venv/bin/gunicorn --pid /run/powerdns-admin/pid --bind unix:/run/powerdns-admin/socket 'powerdnsadmin:create_app()'
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Create systemd socket file
sudo tee $systemd_socket_file > /dev/null << EOF
[Unit]
Description=PowerDNS-Admin socket

[Socket]
ListenStream=/run/powerdns-admin/socket

[Install]
WantedBy=sockets.target
EOF

# Create systemd environment file
sudo mkdir -p $(dirname $systemd_env_file)
sudo tee $systemd_env_file > /dev/null << EOF
[Service]
Environment="FLASK_CONF=../configs/production.py"
EOF

# Create tmpfiles configuration
sudo tee $tmpfiles_config_file > /dev/null << EOF
d /run/powerdns-admin 0755 $pdns_user $pdns_group -
EOF

# Reload systemd and enable PowerDNS-Admin service
sudo systemctl daemon-reload
sudo systemctl start powerdns-admin.socket
sudo systemctl enable powerdns-admin.socket

# Configure Nginx
sudo tee $nginx_config_file > /dev/null << EOF
server {
  listen *:80;
  server_name               $server_name;

  index                     index.html index.htm index.php;
  root                      $powerdns_admin_path;
  access_log                /var/log/nginx/powerdns_admin_access.log combined;
  error_log                 /var/log/nginx/powerdns_admin_error.log;

  client_max_body_size              10m;
  client_body_buffer_size           128k;
  proxy_redirect                    off;
  proxy_connect_timeout             90;
  proxy_send_timeout                90;
  proxy_read_timeout                90;
  proxy_buffers                     32 4k;
  proxy_buffer_size                 8k;
  proxy_set_header                  Host \$host;
  proxy_set_header                  X-Real-IP \$remote_addr;
  proxy_set_header                  X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_headers_hash_bucket_size    64;

  location ~ ^/static/  {
    include  /etc/nginx/mime.types;
    root $powerdns_admin_path/powerdnsadmin;

    location ~*  \.(jpg|jpeg|png|gif)\$ {
      expires 365d;
    }

    location ~* ^.+.(css|js)\$ {
      expires 7d;
    }
  }

  location / {
    proxy_pass            http://unix:/run/powerdns-admin/socket;
    proxy_read_timeout    120;
    proxy_connect_timeout 120;
    proxy_redirect        off;
  }
}
EOF

# Check nginx syntax and restart the service
sudo nginx -t && sudo systemctl restart nginx

# Activate virtual environment and perform database migration
cd $powerdns_admin_path
source venv/bin/activate
export FLASK_APP=powerdnsadmin/__init__.py
export FLASK_CONF=../configs/production.py
flask db upgrade

# Restart PowerDNS-Admin service
sudo systemctl restart powerdns-admin.service

echo "PowerDNS Admin setup is complete. Access it at http://$server_name"
