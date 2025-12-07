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