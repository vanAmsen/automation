#!/bin/bash

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

# Inform user how to run the application
echo "To run the PowerDNS Admin interface, execute: ./run.py"
echo "Remember to configure Nginx or another web server to serve the application in production."

# No need to call 'exit' in a script, it will exit when finished
