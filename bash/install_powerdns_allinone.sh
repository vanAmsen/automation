#!/bin/bash

# => install_powerdns.sh

# Prompt for the database name and password
read -p "Enter the PowerDNS database name: " dbname
read -sp "Enter the PowerDNS database user password: " dbpassword
echo

# Step 1: Update and install MariaDB
sudo apt update && sudo apt upgrade -y
sudo apt install mariadb-server mariadb-client -y

# Step 2: Secure the MariaDB installation (optional)
# Uncomment the line below to secure your MariaDB installation
# sudo mysql_secure_installation

# Step 3: Set up the database and user
sudo mysql -e "CREATE DATABASE ${dbname};"
sudo mysql -e "GRANT ALL ON ${dbname}.* TO '${dbname}'@'localhost' IDENTIFIED BY '${dbpassword}';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Step 4: Set up the PowerDNS tables
sudo mysql ${dbname} <<EOF
CREATE TABLE domains (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INT UNSIGNED DEFAULT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE UNIQUE INDEX name_index ON domains(name);
CREATE TABLE records (
  id                    BIGINT AUTO_INCREMENT,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(64000) DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  change_date           INT DEFAULT NULL,
  disabled              TINYINT(1) DEFAULT 0,
  ordername             VARCHAR(255) BINARY DEFAULT NULL,
  auth                  TINYINT(1) DEFAULT 1,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE INDEX nametype_index ON records(name,type);
CREATE INDEX domain_id ON records(domain_id);
CREATE INDEX ordername ON records (ordername);
CREATE TABLE supermasters (
  ip                    VARCHAR(64) NOT NULL,
  nameserver            VARCHAR(255) NOT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' NOT NULL,
  PRIMARY KEY (ip, nameserver)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE TABLE comments (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL,
  comment               TEXT CHARACTER SET 'utf8' NOT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE INDEX comments_name_type_idx ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);
CREATE TABLE domainmetadata (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE INDEX domainmetadata_idx ON domainmetadata (domain_id, kind);
CREATE TABLE cryptokeys (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL,
  content               TEXT,
  PRIMARY KEY(id)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE INDEX domainidindex ON cryptokeys(domain_id);
CREATE TABLE tsigkeys (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255),
  algorithm             VARCHAR(50),
  secret                VARCHAR(255),
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);

EOF

# Step 2: Install PowerDNS
# Disable systemd-resolved
sudo systemctl disable --now systemd-resolved

# Remove the existing resolv.conf
sudo rm -rf /etc/resolv.conf

# Create a new resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Install PowerDNS
sudo apt-get install pdns-server pdns-backend-mysql -y

# Step 3: Configure PowerDNS
# Configuration of PowerDNS
cat <<EOF | sudo tee /etc/powerdns/pdns.d/pdns.local.gmysql.conf
# MySQL Configuration
launch+=gmysql
gmysql-host=127.0.0.1
gmysql-port=3306
gmysql-dbname=${dbname}
gmysql-user=${dbname}
gmysql-password=${dbpassword}
gmysql-dnssec=yes
EOF

# Set the correct permissions
sudo chmod 640 /etc/powerdns/pdns.d/pdns.local.gmysql.conf
sudo chown pdns: /etc/powerdns/pdns.d/pdns.local.gmysql.conf

# Restart PowerDNS service
sudo systemctl restart pdns

# sudo systemctl status pdns
# Check if PowerDNS service is active
if sudo systemctl is-active --quiet pdns; then
    echo "PowerDNS service is running."
else
    echo "Error: PowerDNS service is not running."
fi

# Check if PowerDNS is listening on port 53
sudo ss -alnp4 | grep pdns

# => install_powerdns_admin.sh

# Prompt for database password
read -sp "Enter the password for PowerDNS Admin's database user: " db_password
echo

# Install dependencies
apt-get update
apt-get install -y python3-dev git libmysqlclient-dev libsasl2-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config apt-transport-https python3-venv build-essential curl libpq-dev

# Install Node.js and Yarn
curl -sL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update
apt-get install -y yarn

# Clone the PowerDNS Admin repository
git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git /opt/web/powerdns-admin

# Navigate to the application directory
cd /opt/web/powerdns-admin

# Set up Python virtual environment
python3 -m venv ./venv
source ./venv/bin/activate

# Upgrade pip and install requirements
pip install --upgrade pip setuptools
pip install psycopg2-binary lxml
sed -i 's/psycopg2==[0-9.]*$/psycopg2-binary/' requirements.txt
pip install -r requirements.txt

# Copy and configure the production settings
cp /opt/web/powerdns-admin/configs/development.py /opt/web/powerdns-admin/configs/production.py

# Generate a random secret key and update the production.py file
secret_key=$(python3 -c "import os; print(os.urandom(24).hex())")
sed -i "s/SECRET_KEY = '.*'/SECRET_KEY = '$secret_key'/" /opt/web/powerdns-admin/configs/production.py
sed -i "s/SQLA_DB_PASSWORD = '.*'/SQLA_DB_PASSWORD = '$db_password'/" /opt/web/powerdns-admin/configs/production.py
sed -i 's/#import urllib.parse/import urllib.parse/' /opt/web/powerdns-admin/configs/production.py

# Set environment variables
export FLASK_CONF=../configs/production.py
export FLASK_APP=powerdnsadmin/__init__.py

# Database schema upgrade, install dependencies, and build assets
flask db upgrade
yarn install --pure-lockfile
flask assets build

# Start the Flask development server
echo "Starting the PowerDNS Admin interface..."
./run.py

# No need to call 'exit' in a script, it will exit when finished

# => install_powerdns_ngnix.sh

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

# => install_powerdns_api.sh

# PowerDNS configuration variables
pdns_config_path="/etc/powerdns/pdns.conf"
api_key=$(openssl rand -hex 16) # Generate a secure random API key
webserver_port="8081"
pdns_version=$(pdns_control version) # Dynamically retrieve PowerDNS version
api_url="http://127.0.0.1:${webserver_port}/" # Use loopback address for API URL

# Configure PowerDNS API settings
echo "Configuring PowerDNS API..."
sudo sed -i "s/^#* *api=.*/api=yes/" $pdns_config_path
sudo sed -i "s/^#* *api-key=.*/api-key=$api_key/" $pdns_config_path
sudo sed -i "s/^#* *webserver=.*/webserver=yes/" $pdns_config_path
sudo sed -i "s/^#* *webserver-port=.*/webserver-port=$webserver_port/" $pdns_config_path
sudo sed -i "s/^#* *webserver-address=.*/webserver-address=0.0.0.0/" $pdns_config_path

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

