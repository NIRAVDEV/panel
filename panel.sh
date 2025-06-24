#!/bin/bash

set -e

# ========== 0. Root Check ==========
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Please run as root (sudo)."
  exit 1
fi

# ========== 1. Update System ==========
echo "🔄 Updating system..."
apt update && apt upgrade -y

# ========== 2. Install Dependencies ==========
echo "📦 Installing required packages..."
apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg unzip git make dos2unix tar sudo nginx mariadb-server redis-server php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis}

# ========== 3. Add PHP Repo ==========
add-apt-repository -y ppa:ondrej/php
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
apt update

# ========== 4. Install Composer & Yarn ==========
echo "📦 Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
echo "📦 Installing Yarn globally..."
npm i -g yarn

# ========== 5. Install NVM & Node.js v20 ==========
echo "📦 Installing Node.js 20 via NVM..."
export NVM_DIR="$HOME/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
. "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20

# ========== 6. Download and Extract MythicalDash ==========
echo "📁 Setting up MythicalDash directory..."
mkdir -p /var/www/mythicaldash-v3
cd /var/www/mythicaldash-v3
curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
unzip -o MythicalDash.zip -d /var/www/mythicaldash-v3
chown -R www-data:www-data /var/www/mythicaldash-v3/*

# ========== 7. Install Panel Dependencies ==========
echo "📦 Installing frontend & backend dependencies..."
cd /var/www/mythicaldash-v3
make install

# ========== 8. Configure MariaDB Charset ==========
echo "🛠️ Updating MariaDB charset settings..."
sed -i '/^#collation-server/a collation-server = utf8mb4_general_ci' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-server/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-server/a character-set-server = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^character-set-collations/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^#character-set-collations/a character-set-collations = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

# ========== 9. MySQL Setup ==========
echo "🔐 Database Setup"
echo "You will now enter MariaDB CLI to create user & DB."
echo "❗ Please enter the root password if prompted (default is blank unless changed)."

mysql -u root -p <<EOF
CREATE USER 'mythicaldash_remastered'@'127.0.0.1' IDENTIFIED BY 'l0v3r@comput3r!';
CREATE DATABASE mythicaldash_remastered;
GRANT ALL PRIVILEGES ON mythicaldash_remastered.* TO 'mythicaldash_remastered'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
EOF

# ========== 10. Make Build & Production ==========
make set-prod
make release || make get-frontend

# ========== 11. Setup Crons ==========
echo "⏲️ Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "* * * * * bash /var/www/mythicaldash-v3/backend/storage/cron/runner.bash >> /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/mythicaldash-v3/backend/storage/cron/runner.php >> /dev/null 2>&1") | crontab -

# ========== 12. Final Panel Setup ==========
php mythicaldash setup
php mythicaldash migrate
php mythicaldash pterodactyl configure
php mythicaldash init

echo "✅ MythicalDash v3 installation complete!"
echo "📍 Visit your panel directory: /var/www/mythicaldash-v3"
