#!/bin/bash
set -e

# Cambiar hostname
sudo hostnamectl set-hostname DBmanuelrwordpress

# Instalar MariaDB
sudo apt update
sudo apt install mariadb-server -y

sudo mysql <<EOF
CREATE DATABASE manuelrwordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE USER 'manuelr'@'10.0.1.61' IDENTIFIED BY 'abcd';
GRANT ALL PRIVILEGES ON manuelrwordpress.* TO 'manuelr'@'10.0.1.61';

CREATE USER 'manuelr'@'10.0.1.26' IDENTIFIED BY 'abcd';
GRANT ALL PRIVILEGES ON manuelrwordpress.* TO 'manuelr'@'10.0.1.26';

FLUSH PRIVILEGES;
EOF

sudo sed -i 's/^bind-address.*/bind-address = 10.0.2.244/' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb