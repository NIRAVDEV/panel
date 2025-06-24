#!/bin/bash

set -e

echo "🧰 Starting MythicalDash v3 installation for Ubuntu 22.04 with PHP 8.2..."

# ===== System Prep =====
echo "🔧 Updating packages..."
apt update && apt upgrade -y

echo "📦 Installing base dependencies..."
apt install -y software-properties-common curl ca-certificates apt-transport-https lsb-release gnupg unzip git make dos2unix tar sudo

# ===== PHP 8.2 Install =====
echo "➕ Adding PHP 8.2 repository..."
add-apt-repository -y ppa:ondrej/php
apt update

echo "📦 Installing PHP 8.2 and extensions..."
apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl php8.2-bcmath php8.2-zip php8.2-redis

# ===== MariaDB & Redis =====
echo "🛢️ Installing MariaDB and Redis..."
apt install -y mariadb-server redis-server

# ===== Composer & Yarn =====
echo "📦 Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "📦 Installing Node.js 20 and Yarn..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g yarn

# ===== Download MythicalDash =====
echo "📁 Setting up MythicalDash files..."
mkdir -p /var/www/mythicaldash-v3
cd /var/www/mythicaldash-v3
curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
unzip -o MythicalDash.zip -d /var/www/mythicaldash-v3
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# ===== Install Panel Dependencies =====
cd /var/www/mythicaldash-v3
echo "📦 Installing backend/frontend dependencies..."
make install

# ===== MariaDB Charset Fix =====
echo "🛠️ Configuring MariaDB charset..."
sed -i '/^#collation-server/a collation-server = utf8mb4_general_ci' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-server/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-server/a character-set-server = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-collations/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-collations/a character-set-collations = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

# ===== Database Setup =====
echo "🔐 Creating database & user in MariaDB..."
mysql -u root <<EOF
CREATE USER 'mythicaldash_remastered'@'127.0.0.1' IDENTIFIED BY 'l0v3r@comput3r;
CREATE DATABASE mythicaldash_remastered;
GRANT ALL PRIVILEGES ON mythicaldash_remastered.* TO 'mythicaldash_remastered'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# ===== Finalizing Setup =====
echo "⚙️ Finalizing panel setup..."
make set-prod
make release || make get-frontend

# ===== Cron Setup =====
echo "⏲️ Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "* * * * * bash /var/www/mythicaldash-v3/backend/storage/cron/runner.bash >> /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/mythicaldash-v3/backend/storage/cron/runner.php >> /dev/null 2>&1") | crontab -

# ===== MythicalDash Init =====
php mythicaldash setup
php mythicaldash migrate
php mythicaldash pterodactyl configure
php mythicaldash init

echo "✅ MythicalDash v3 installed successfully!"
echo "🔗 Visit your panel in browser (point domain/IP to this server)."
