# Wordpress_AWS_ManuelR

Manual de Administrador – Despliegue WordPress HA en AWS
1. Arquitectura de la solución
Capas
Capa 1 (Pública):

Balanceador de carga Apache (BalanceadorManuel).

Acceso desde Internet (HTTP/HTTPS).

Conectividad solo hacia Capa 2.

Capa 2 (Privada):

Dos servidores Apache (Web1Manuel, Web2Manuel).

Servidor NFS (NFSManuel) exportando /var/www/html/wordpress.

Conectividad hacia Capa 3 (BBDD).

Capa 3 (Privada):

Servidor MariaDB/MySQL (DBManuel).

Solo accesible desde Capa 2.

No accesible desde Capa 1.

2. Seguridad
Grupos de Seguridad (SG)
Grupo	Permite	Origen
SG-Balanceador	80, 443	Internet (0.0.0.0/0)
SG-Web	80	SG-Balanceador
SG-NFS	2049 (NFS), 111 (rpcbind)	SG-Web
SG-DB	3306	SG-Web
ACLs
Capa 1 → Capa 3: Bloqueada.

Capa 2 → Capa 3: Permitida.

Capa 1 → Capa 2: Permitida.

3. Script de aprovisionamiento (Bash)
Ejemplo de script deploy_wordpress.sh:

bash
#!/bin/bash
# Script de aprovisionamiento WordPress HA en AWS
# Autor: Manuel Ramírez Rodríguez

# Variables
ALUMNO="Manuel"
DOMAIN="midominio.com"
WP_DIR="/var/www/html/wordpress"

# Instalar Apache en balanceador
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

# Instalar Apache en servidores web
setup_web() {
  hostnamectl set-hostname "$1${ALUMNO}"
  apt update && apt install -y apache2 php php-mysql nfs-common
  mkdir -p $WP_DIR
  echo "$2:/var/www/html/wordpress $WP_DIR nfs defaults 0 0" >> /etc/fstab
  mount -a
  systemctl restart apache2
}

# Instalar NFS
setup_nfs() {
  hostnamectl set-hostname "NFS${ALUMNO}"
  apt update && apt install -y nfs-kernel-server
  mkdir -p $WP_DIR
  chown -R www-data:www-data $WP_DIR
  echo "/var/www/html/wordpress *(rw,sync,no_subtree_check)" >> /etc/exports
  exportfs -a
  systemctl restart nfs-kernel-server
}

# Instalar MariaDB
setup_db() {
  hostnamectl set-hostname "DB${ALUMNO}"
  apt update && apt install -y mariadb-server
  mysql -e "CREATE DATABASE wordpress;"
  mysql -e "CREATE USER 'wpuser'@'%' IDENTIFIED BY 'wpPass123';"
  mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';"
  mysql -e "FLUSH PRIVILEGES;"
}

# Personalizar WordPress
customize_wp() {
  echo "<h1>WordPress de $ALUMNO</h1>" > $WP_DIR/index.php
}

# Ejecución
case $1 in
  balanceador) setup_balanceador ;;
  web1) setup_web "Web1" "NFS${ALUMNO}" ;;
  web2) setup_web "Web2" "NFS${ALUMNO}" ;;
  nfs) setup_nfs ;;
  db) setup_db ;;
  wp) customize_wp ;;
  *) echo "Uso: $0 {balanceador|web1|web2|nfs|db|wp}" ;;
esac
4. Configuración de HTTPS
Asociar Elastic IP al balanceador.

Configurar DNS en el dominio del alumno (midominio.com → Elastic IP).

Instalar Certbot en balanceador:

bash
apt install -y certbot python3-certbot-apache
certbot --apache -d midominio.com -d www.midominio.com
5. Documento Técnico (Markdown)
En el repositorio GitHub incluir un archivo README.md con:

Descripción de la arquitectura.

Pasos de aprovisionamiento.

Configuración de seguridad (SG + ACLs).

Personalización de WordPress.

URL pública de acceso.

6. Validación
Acceso externo solo por HTTPS.

Balanceador distribuye tráfico entre Web1Manuel y Web2Manuel.

WordPress personalizado muestra el nombre del alumno.

Base de datos funcional en DBManuel.

Certificado válido instalado.
