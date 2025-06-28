#!/bin/bash

set -e

# Update package lists and upgrade the system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y git curl wget sudo neofetch unzip software-properties-common mariadb-server redis nginx certbot php php-cli php-fpm php-json php-mysql php-zip php-gd php-mbstring php-curl php-xml php-pear composer

# Add PHP 8.1 repository (you may need to adjust this for different versions)
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-get install -y php8.1-cli php8.1-fpm php8.1-json php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml

# Configure Nginx (replace example.com with your domain)
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default

cat <<EOF >/etc/nginx/sites-available/mythicaldash
server {
    listen 80;
    server_name example.com;
    root /var/www/mythicaldash/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock; # Adjust PHP version if needed
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/mythicaldash /etc/nginx/sites-enabled/

# Reload Nginx
systemctl restart nginx

# Optionally, set up Let's Encrypt SSL (replace example.com with your domain)
# certbot --nginx -d example.com -n --agree-tos --email your_email@example.com

# Set up MariaDB database and user
MYSQL_ROOT_PASSWORD="root_password"
MYSQL_DATABASE="mythicaldash"
MYSQL_USER="mythicaldash"
MYSQL_PASSWORD="dash_password"

# Secure MySQL installation
# mysql_secure_installation

cat <<EOF | mysql -u root -p${MYSQL_ROOT_PASSWORD}
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Download MythicalDash
cd /var/www/
git clone https://github.com/MythicalLTD/MythicalDash.git
cd mythicaldash

# Install PHP dependencies
composer install --no-interaction --optimize-autoloader

# Set up environment variables
cp .env.example .env
# Modify .env file with correct database credentials and app URL
sed -i "s/DB_DATABASE=homestead/DB_DATABASE=${MYSQL_DATABASE}/g" .env
sed -i "s/DB_USERNAME=homestead/DB_USERNAME=${MYSQL_USER}/g" .env
sed -i "s/DB_PASSWORD=secret/DB_PASSWORD=${MYSQL_PASSWORD}/g" .env
sed -i "s/APP_URL=http:\/\/localhost/APP_URL=http:\/\/example.com/g" .env # Replace example.com

# Generate app key
php artisan key:generate

# Run database migrations and seeders
php artisan migrate --force
php artisan db:seed --force

# Set correct file permissions
chown -R www-data:www-data /var/www/mythicaldash
chmod -R 755 /var/www/mythicaldash/storage
chmod -R 755 /var/www/mythicaldash/bootstrap/cache

# Create a systemd service to manage the MythicalDash queue worker
cat <<EOF >/etc/systemd/system/mythicaldash-queue.service
[Unit]
Description=MythicalDash Queue Worker
After=redis.service
Requires=redis.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/mythicaldash
ExecStart=php artisan queue:work --tries=3
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mythicaldash-queue.service
systemctl start mythicaldash-queue.service

# Display completion message
echo "MythicalDash installation complete!"
echo "Access your MythicalDash instance at http://example.com (replace with your actual domain)."
