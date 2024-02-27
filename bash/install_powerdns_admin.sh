#!/bin/bash

# Prompt for database password
read -sp "Enter the password for PowerDNS Admin's database user: " db_password
echo

# Install PowerDNS Admin Dependencies
apt install python3-dev -y
apt install -y git libmysqlclient-dev libsasl2-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config apt-transport-https python3-venv build-essential curl

# Fetch and install Node.js (using version 16 instead of deprecated 14)
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
apt install -y nodejs

# Install Yarn package manager
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt update -y
apt install yarn -y

# Clone PowerDNS Admin repository
git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git /opt/web/powerdns-admin

# Setup application
cd /opt/web/powerdns-admin

# Create and activate Python virtual environment
python3 -m venv ./venv
source ./venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install requirements
pip install -r requirements.txt

# Configure PowerDNS Admin
cp /opt/web/powerdns-admin/configs/development.py /opt/web/powerdns-admin/configs/production.py

# Generate a random secret key and insert it into the production config
secret_key=$(python3 -c "import os; print(os.urandom(16).hex())")
sed -i "s/'e951e5a1f4b94151b360f47edf596dd2'/'$secret_key'/g" /opt/web/powerdns-admin/configs/production.py

# Insert the provided database password into the production config
sed -i "s/'changeme'/'$db_password'/g" /opt/web/powerdns-admin/configs/production.py

# Export app configuration variables
export FLASK_CONF=../configs/production.py
export FLASK_APP=powerdnsadmin/__init__.py

# Upgrade the database schema
flask db upgrade

# Install project dependencies and build assets
yarn install --pure-lockfile
flask assets build

# Run the application (For production use, this should be replaced with a proper WSGI server)
echo "You can now run the PowerDNS Admin interface using the command: ./run.py"

# Setup PowerDNS Admin as a service
cat > /etc/systemd/system/powerdns-admin.service << EOF
[Unit]
Description=PowerDNS-Admin
Requires=powerdns-admin.socket
After=network.target

[Service]
User=root
Group=root
PIDFile=/run/powerdns-admin/pid
WorkingDirectory=/opt/web/powerdns-admin
ExecStartPre=/bin/bash -c 'mkdir -p /run/powerdns-admin/'
ExecStart=/opt/web/powerdns-admin/venv/bin/gunicorn --pid /run/powerdns-admin/pid --bind unix:/run/powerdns-admin/socket 'powerdnsadmin:create_app()'
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Create a socket file
cat > /etc/systemd/system/powerdns-admin.socket << EOF
[Unit]
Description=PowerDNS-Admin socket

[Socket]
ListenStream=/run/powerdns-admin/socket

[Install]
WantedBy=sockets.target
EOF

# Create an environment file
echo 'd /run/powerdns-admin 0755 pdns pdns -' > /etc/tmpfiles.d/powerdns-admin.conf

# Reload the systemd daemon and start the service
systemctl daemon-reload
systemctl start powerdns-admin.service powerdns-admin.socket
systemctl enable powerdns-admin.service powerdns-admin.socket

# Check the status of the PowerDNS Admin service
systemctl status powerdns-admin.service powerdns-admin.socket

# Install and configure Nginx
apt install nginx -y

# Create Nginx config file for PowerDNS Admin
cat > /etc/nginx/sites-available/powerdns-admin.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    index index.html index.htm index.php;
    root /opt/web/powerdns-admin;

    access_log /var/log/nginx/powerdns-admin.access.log;
    error_log /var/log/nginx/powerdns-admin.error.log;

    client_max_body_size 10m;
    client_body_buffer_size 128k;

    proxy_redirect off;
    proxy_connect_timeout 90;
    proxy_send_timeout 90;
    proxy_read_timeout 90;
    proxy_buffers 32 4k;
    proxy_buffer_size 8k;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_headers_hash_bucket_size 64;

    location / {
        proxy_pass http://unix:/run/powerdns-admin/socket;
        include /etc/nginx/proxy_params;
    }

    location ~ ^/static/ {
        include /etc/nginx/mime.types;
        root /opt/web/powerdns-admin/powerdnsadmin/static;
    }
}
EOF

# Enable the new site and reload Nginx
ln -s /etc/nginx/sites-available/powerdns-admin.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Change the ownership of powerdns-admin to www-data
chown -R www-data:www-data /opt/web/powerdns-admin

# Output completion message
echo "PowerDNS Admin setup is complete. Access it at http://localhost:9191"

# Exit from the root user to a regular state
exit
