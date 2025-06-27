#!/bin/bash

set -e

DOMAIN="example.com"  # ← CHANGE THIS to your domain
DB_PASSWORD="yourSecurePassword"  # ← CHANGE this password

echo "📦 Installing MythicalDash v3 (Node 22, PHP 8.2, NGINX)..."

# === Update System ===
apt update && apt upgrade -y
apt install -y software-properties-common curl ca-certificates apt-transport-https gnupg unzip git make dos2unix sudo build-essential

# === PHP & Required Extensions 
sudo apt update && sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl php8.2-bcmath php8.2-zip php8.2-redis

# === MariaDB, Redis, NGINX ===
apt install -y mariadb-server redis-server nginx
service mariadb start
service nginx start
service redis-server start

# === Install NVM + Node.js 22 ===
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Load NVM (important for non-login shell)
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

# Install and use Node 22
nvm install 22
nvm use 22

# Set it as default
nvm alias default 22

# === Yarn & Composer ===
npm install -g yarn
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# === Download MythicalDash ===
mkdir -p /var/www/mythicaldash-v3
cd /var/www/mythicaldash-v3
curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
unzip -o MythicalDash.zip -d .
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# === Build Frontend ===
cd frontend
yarn install
yarn build

# === Install Backend Dependencies ===
cd ../backend
composer install --no-interaction --prefer-dist --optimize-autoloader

# === MySQL Setup ===
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

# === Certbot SSL ===
apt install -y certbot python3-certbot-nginx
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
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag "index, follow";
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /mc-admin {
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
        try_files \$uri \$uri/ /index.php?\$query_string;
        include fastcgi_params;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/MythicalDashRemastered.conf /etc/nginx/sites-enabled/MythicalDashRemastered.conf
nginx -t && service nginx reload

# === MythicalDash Setup ===
cd /var/www/mythicaldash-v3
php mythicaldash setup
php mythicaldash migrate
php mythicaldash pterodactyl configure
php mythicaldash init
php mythicaldash makeAdmin

# === Permissions Fix ===
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# === SSL Auto Renew (Cron) ===
(crontab -l 2>/dev/null; echo "0 23 * * * certbot renew --quiet --deploy-hook 'service nginx reload'") | crontab -

echo "✅ MythicalDash installed and running at https://${DOMAIN}"
