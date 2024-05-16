#!/bin/bash

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
  published             TINYINT(1) DEFAULT 0,   -- Added the published column
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

# Step 5: Install PowerDNS
# Disable systemd-resolved
sudo systemctl disable --now systemd-resolved

# Remove the existing resolv.conf
sudo rm -rf /etc/resolv.conf

# Create a new resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Install PowerDNS
sudo apt-get install pdns-server pdns-backend-mysql -y

# Step 6: Configure PowerDNS
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

# Check if PowerDNS service is active
if sudo systemctl is-active --quiet pdns; then
    echo "PowerDNS service is running."
else
    echo "Error: PowerDNS service is not running."
fi

# Check if PowerDNS is listening on port 53
sudo ss -alnp4 | grep pdns
