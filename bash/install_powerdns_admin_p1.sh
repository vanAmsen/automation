#!/bin/bash

# Prompt for database password and server name or IP address
read -sp "Enter the password for PowerDNS Admin's database user: " db_password
echo
read -p "Enter the server name or IP address for PowerDNS Admin: " server_name
echo

# Install dependencies
apt install -y python3-dev git libmysqlclient-dev libsasl2-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config apt-transport-https python3-venv build-essential curl libpq-dev

# Install Node.js and Yarn
curl -sL https://deb.nodesource.com/setup_18.x | sudo bash -
apt install -y nodejs yarn

# Clone PowerDNS-Admin repository
git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git /opt/web/powerdns-admin

# Setup application
cd /opt/web/powerdns-admin
python3 -m venv ./venv
source ./venv/bin/activate
pip install --upgrade pip setuptools
pip install psycopg2-binary lxml
pip install -r requirements.txt

# Configure PowerDNS-Admin
cp /opt/web/powerdns-admin/configs/development.py /opt/web/powerdns-admin/configs/production.py
sed -i 's/#import urllib.parse/import urllib.parse/' /opt/web/powerdns-admin/configs/production.py
secret_key=$(python3 -c "import os; print(os.urandom(16).hex())")
sed -i "s/SECRET_KEY = '.*'/SECRET_KEY = '$secret_key'/" /opt/web/powerdns-admin/configs/production.py
sed -i "s/SQLA_DB_PASSWORD = '.*'/SQLA_DB_PASSWORD = '$db_password'/" /opt/web/powerdns-admin/configs/production.py
export FLASK_CONF=../configs/production.py
export FLASK_APP=powerdnsadmin/__init__.py
flask db upgrade
yarn install --pure-lockfile
flask assets build

# Install and configure gunicorn as a service
apt install -y gunicorn
cat > /etc/systemd/system/powerdns-admin.service << EOF
[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/web/powerdns-admin
ExecStart=/opt/web/powerdns-admin/venv/bin/gunicorn 'powerdnsadmin:create_app()' -b 0.0.0.0:9191
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start and enable PowerDNS-Admin service
systemctl daemon-reload
systemctl start powerdns-admin.service
systemctl enable powerdns-admin.service

# Check if the service is running
if systemctl is-active --quiet powerdns-admin.service; then
    echo "PowerDNS Admin is running and enabled."
else
    echo "Error: PowerDNS Admin did not start correctly."
fi

# Setup Nginx as a reverse proxy
apt install -y nginx
cat > /etc/nginx/sites-available/powerdns-admin.conf << EOF
server {
    listen 80;
    server_name $server_name;

    location / {
        proxy_pass http://localhost:9191;
        include /etc/nginx/proxy_params;
    }
}
EOF

# Enable the site and reload Nginx
ln -s /etc/nginx/sites-available/powerdns-admin.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Change the ownership of powerdns-admin to www-data
chown -R www-data:www-data /opt/web/powerdns-admin

# Output completion message
echo "PowerDNS Admin setup is complete. Access it at http://$server_name"
