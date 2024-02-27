#!/bin/bash

# Prompt for database password
read -sp "Enter the password for PowerDNS Admin's database user: " db_password
echo
# Prompt for server name or IP address
read -p "Enter the server name or IP address for PowerDNS Admin: " server_name
echo

# Install PowerDNS Admin Dependencies
apt install python3-dev -y
apt install -y git libmysqlclient-dev libsasl2-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config apt-transport-https python3-venv build-essential curl

# Fetch and install Node.js (using version 18 instead of deprecated 14)
curl -sL https://deb.nodesource.com/setup_18.x | sudo bash -
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

# Upgrade pip and setuptools
pip install --upgrade pip setuptools

# Install PostgreSQL development package for psycopg2
apt-get install -y libpq-dev

# Install additional system libraries for lxml or other dependencies
apt-get install libxml2-dev libxslt1-dev

# Install requirements, using binary packages for complex dependencies
pip install psycopg2-binary
pip install lxml
pip install -r requirements.txt

# Configure PowerDNS Admin
cp /opt/web/powerdns-admin/configs/development.py /opt/web/powerdns-admin/configs/production.py

# Uncomment the library import line
sed -i 's/#import urllib.parse/import urllib.parse/' /opt/web/powerdns-admin/configs/production.py

# Generate a random secret key
secret_key=$(python3 -c "import os; print(os.urandom(16).hex())")

# Insert the randomly generated secret key
sed -i "s/SECRET_KEY = '.*'/SECRET_KEY = '$secret_key'/" /opt/web/powerdns-admin/configs/production.py

# Insert the provided database password
sed -i "s/SQLA_DB_PASSWORD = '.*'/SQLA_DB_PASSWORD = '$db_password'/" /opt/web/powerdns-admin/configs/production.py

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
