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

Archivo: `deploy_wordpress.sh`

```bash
#!/bin/bash
# Script de aprovisionamiento WordPress HA en AWS
# Autor: Manuel Ramírez Rodríguez

ALUMNO="Manuel"
DOMAIN="midominio.com"
WP_DIR="/var/www/html/wordpress"

setup_balanceador() {
  hostnamectl set-hostname "Balanceador${ALUMNO}"
  apt update && apt install -y apache2
  a2enmod proxy proxy_balancer proxy_http ssl
  cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
  ProxyPreserveHost On
  ProxyPass / balancer://cluster/
  ProxyPassReverse / balancer://cluster/
</VirtualHost>

<Proxy balancer://cluster>
  BalancerMember http://Web1${ALUMNO}:80
  BalancerMember http://Web2${ALUMNO}:80
</Proxy>
EOF
  systemctl restart apache2
}

setup_web() {
  hostnamectl set-hostname "$1${ALUMNO}"
  apt update && apt install -y apache2 php php-mysql nfs-common
  mkdir -p $WP_DIR
  echo "$2:/var/www/html/wordpress $WP_DIR nfs defaults 0 0" >> /etc/fstab
  mount -a
  systemctl restart apache2
}

setup_nfs() {
  hostnamectl set-hostname "NFS${ALUMNO}"
  apt update && apt install -y nfs-kernel-server
  mkdir -p $WP_DIR
  chown -R www-data:www-data $WP_DIR
  echo "/var/www/html/wordpress *(rw,sync,no_subtree_check)" >> /etc/exports
  exportfs -a
  systemctl restart nfs-kernel-server
}

setup_db() {
  hostnamectl set-hostname "DB${ALUMNO}"
  apt update && apt install -y mariadb-server
  mysql -e "CREATE DATABASE wordpress;"
  mysql -e "CREATE USER 'wpuser'@'%' IDENTIFIED BY 'wpPass123';"
  mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';"
  mysql -e "FLUSH PRIVILEGES;"
}

customize_wp() {
  echo "<h1>WordPress de $ALUMNO</h1>" > $WP_DIR/index.php
}

case $1 in
  balanceador) setup_balanceador ;;
  web1) setup_web "Web1" "NFS${ALUMNO}" ;;
  web2) setup_web "Web2" "NFS${ALUMNO}" ;;
  nfs) setup_nfs ;;
  db) setup_db ;;
  wp) customize_wp ;;
  *) echo "Uso: $0 {balanceador|web1|web2|nfs|db|wp}" ;;
esac
