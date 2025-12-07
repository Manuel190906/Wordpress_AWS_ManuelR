# Despliegue WordPress HA en AWS – Documento Técnico

## 1. Arquitectura

### Capas
- **Capa 1 (Pública):** Balanceador Apache (`BalanceadorManuel`).
- **Capa 2 (Privada):** Dos servidores Apache (`Web1Manuel`, `Web2Manuel`) + Servidor NFS (`NFSManuel`).
- **Capa 3 (Privada):** Servidor MariaDB/MySQL (`DBManuel`).

### Reglas de conectividad
- Acceso externo solo a Capa 1.
- Capa 1 no conecta directamente con Capa 3.
- Capa 2 conecta con Capa 3.

---

## 2. Seguridad

### Grupos de Seguridad
| Grupo          | Puertos     | Origen          |
|----------------|-------------|-----------------|
| SG-Balanceador | 80, 443     | Internet        |
| SG-Web         | 80          | SG-Balanceador  |
| SG-NFS         | 2049, 111   | SG-Web          |
| SG-DB          | 3306        | SG-Web          |

### ACLs
- Bloquear tráfico Capa 1 → Capa 3.
- Permitir Capa 1 → Capa 2.
- Permitir Capa 2 → Capa 3.

---

## 3. Aprovisionamiento (Script Bash)

Balanceador: ``

```bash
<VirtualHost *:80>
    ServerName manuelraws.myddns.me
    Redirect permanent / https://manuelraws.myddns.me/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/load-balancer-ssl.conf > /dev/null <<EOF
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName manuelraws.myddns.me

    SSLEngine On
    SSLCertificateFile /etc/letsencrypt/live/manuelraws.myddns.me/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/manuelraws.myddns.me/privkey.pem

    <Proxy "balancer://mycluster">
        ProxySet stickysession=JSESSIONID|ROUTEID
        BalancerMember http://10.0.1.26:80
        BalancerMember http://10.0.1.61:80
    </Proxy>

    ProxyPass "/" "balancer://mycluster/"
    ProxyPassReverse "/" "balancer://mycluster/"
</VirtualHost>
</IfModule>
EOF

sudo a2dissite 000-default.conf
sudo a2ensite load-balancer.conf
sudo a2ensite load-balancer-ssl.conf
sudo systemctl reload apache2
ssh -i "vockey.pem" admin@100.30.149.125
```

NFS: ``

```bash
#!/bin/bash
set -e
sudo hostnamectl set-hostname WEB1manuelraws
sudo apt update
sudo apt install nfs-common apache2 php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring php-xmlrpc php-zip php-soap php-intl -y

sudo mkdir -p /nfs/general

sudo mount 10.0.1.100:/var/nfs/general /nfs/general
echo "10.0.1.100:/var/nfs/general  /nfs/general  nfs _netdev,auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab

sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf

sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName https://manuelraws.myddns.me
    DocumentRoot /nfs/general/wordpress/

    <Directory /nfs/general/wordpress>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

sudo a2dissite 000-default.conf
sudo a2ensite wordpress.conf
sudo systemctl reload apache2
```

WEB's: ``

```bash

#!/bin/bash
set -e
sudo hostnamectl set-hostname WEBmanuelramirez

sudo apt update
sudo apt install nfs-common apache2 php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring -y

sudo mkdir -p /nfs/general

sudo mount 10.0.1.100:/var/nfs/general /nfs/general
echo "10.0.1.100:/var/nfs/general  /nfs/general  nfs _netdev,auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab

sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf

sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName https://manuelraws.myddns.me
    DocumentRoot /nfs/general/wordpress/

    <Directory /nfs/general/wordpress>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

sudo a2dissite 000-default.conf
sudo a2ensite wordpress.conf
sudo systemctl reload apache2
```
WEB's: ``

```bash
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
```
