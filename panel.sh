#!/bin/bash

set -e

echo "🧰 Installing MythicalDash v3 on Ubuntu 20.04 with PHP 8.2"

# ===== Base Setup =====
apt update && apt upgrade -y
apt install -y software-properties-common curl ca-certificates apt-transport-https gnupg lsb-release unzip git make dos2unix sudo

# ===== PHP 8.2 via Ondrej PPA =====
add-apt-repository -y ppa:ondrej/php
apt update
apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl php8.2-bcmath php8.2-zip php8.2-redis

# ===== Database & Services =====
apt install -y mariadb-server redis-server nginx

# ===== Node.js 20 and Yarn =====
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g yarn

# ===== Composer =====
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ===== MythicalDash Files =====
mkdir -p /var/www/mythicaldash-v3
cd /var/www/mythicaldash-v3
curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
unzip -o MythicalDash.zip -d /var/www/mythicaldash-v3
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# ===== Install Dependencies =====
cd /var/www/mythicaldash-v3
make install

# ===== MariaDB Charset Config =====
sed -i '/^#collation-server/a collation-server = utf8mb4_general_ci' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-server/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-server/a character-set-server = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-collations/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-collations/a character-set-collations = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

# ===== MariaDB Setup =====
echo "🔐 Setting up MariaDB user and database..."
mysql -u root <<EOF
CREATE USER 'mythicaldash_remastered'@'127.0.0.1' IDENTIFIED BY 'yourPassword';
CREATE DATABASE mythicaldash_remastered;
GRANT ALL PRIVILEGES ON mythicaldash_remastered.* TO 'mythicaldash_remastered'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# ===== Finalize Panel =====
make set-prod
make release || make get-frontend

# ===== Cron Jobs =====
(crontab -l 2>/dev/null; echo "* * * * * bash /var/www/mythicaldash-v3/backend/storage/cron/runner.bash >> /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/mythicaldash-v3/backend/storage/cron/runner.php >> /dev/null 2>&1") | crontab -

# ===== CLI Setup =====
php mythicaldash setup
php mythicaldash migrate
php mythicaldash pterodactyl configure
php mythicaldash init

echo "✅ MythicalDash v3 installation complete!"
echo "📍 Navigate to: /var/www/mythicaldash-v3"
echo "🔐 Don't forget to update your DB password in the script!"
