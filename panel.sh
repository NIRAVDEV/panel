#!/bin/bash

set -e

DOMAIN="example.com"  # 👈 CHANGE THIS to your real domain
DB_PASSWORD="yourSecurePassword"  # 👈 Change DB password

echo "📦 Installing MythicalDash v3 (NGINX, PHP 8.2, Certbot)..."

# === Update + Basic Tools ===
apt update && apt upgrade -y
apt install -y software-properties-common curl ca-certificates apt-transport-https gnupg unzip git make dos2unix sudo

# === Add PHP PPA & Install PHP 8.2 ===
add-apt-repository -y ppa:ondrej/php
apt update
apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl php8.2-bcmath php8.2-zip php8.2-redis

# === MariaDB, Redis, NGINX ===
apt install -y mariadb-server redis-server nginx
service mariadb start
service nginx start
service redis-server start

# === Node 20, Yarn, Composer ===
curl -fsSL https://deb.nodesource.com/setup_20.9.0 | bash -
apt install -y nodejs
npm install -g yarn
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# === Download & Unpack MythicalDash ===
mkdir -p /var/www/mythicaldash-v3
cd /var/www/mythicaldash-v3
curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
unzip -o MythicalDash.zip -d /var/www/mythicaldash-v3
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# === Install Backend + Frontend ===
cd /var/www/mythicaldash-v3
make install

# === Create MySQL DB and User ===
mysql -u root <<EOF
CREATE USER 'mythicaldash_remastered'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
CREATE DATABASE mythicaldash_remastered;
GRANT ALL PRIVILEGES ON mythicaldash_remastered.* TO 'mythicaldash_remastered'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# === MariaDB Charset Config ===
sed -i '/^#collation-server/a collation-server = utf8mb4_general_ci' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-server/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-server/a character-set-server = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-collations/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-collations/a character-set-collations = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
service mariadb restart

# === SSL: Certbot (Let's Encrypt) ===
apt install -y certbot python3-certbot-nginx

# === Generate SSL Certificate (Preferred Method) ===
certbot certonly --nginx -d "$DOMAIN"

# === Configure NGINX ===
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/MythicalDashRemastered.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/mythicaldash-v3/frontend/dist;
    index index.html;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag "index, follow";
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    proxy_hide_header X-Powered-By;
    proxy_hide_header Server;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /mc-admin {
        add_header X-Robots-Tag "noindex, nofollow";
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:6000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /i/ {
        proxy_pass http://localhost:6000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /attachments {
        alias /var/www/mythicaldash-v3/backend/public/attachments;
    }
}

server {
    listen 6000;
    server_name localhost;
    root /var/www/mythicaldash-v3/backend/public;

    index index.php;
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    error_log /var/www/mythicaldash-v3/backend/storage/logs/mythicaldash-v3.log error;

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_hide_header X-Powered-By;
        proxy_hide_header Server;
        add_header Server "MythicalDash";
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable NGINX site
ln -sf /etc/nginx/sites-available/MythicalDashRemastered.conf /etc/nginx/sites-enabled/MythicalDashRemastered.conf
nginx -t && service nginx reload

# === Panel Setup ===
cd /var/www/mythicaldash-v3
php mythicaldash setup
php mythicaldash migrate
php mythicaldash pterodactyl configure
php mythicaldash init
php mythicaldash makeAdmin

# === Permissions ===
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# === SSL Auto Renewal (cron job at 11:00 PM) ===
(crontab -l ; echo "0 23 * * * certbot renew --quiet --deploy-hook 'service nginx restart'") | crontab -

echo "✅ MythicalDash is now running at https://${DOMAIN}"
