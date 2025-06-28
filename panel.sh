#!/bin/bash
set -e

# Update package lists and upgrade the system
apt update && sudo apt install software-properties-common -y
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y git curl wget sudo neofetch unzip software-properties-common mariadb-server redis nginx certbot php8.2 php8.2-cli php8.2-fpm php8.2-json php8.2-mysql php8.2-pdo php8.2-gd php8.2-mbstring php8.2-tokenizer php8.2-xml php8.2-curl php8.2-zip php8.2-opcache

# Install Composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Set timezone non-interactively
tzselect <<< $'1\n9\n' | tee /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

# Configure Nginx
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default

cat <<EOF >/etc/nginx/sites-available/mythicaldash.conf
server {
    listen 80;
    listen [::]:80;
    server_name _; # Replace with your domain or IP address
    root /var/www/mythicaldash/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock; # Adjust if needed
    }

    location ~ /\.ht {
        deny all;
    }

    # Certbot configuration (SSL - optional, configure after install)
    # location /.well-known/acme-challenge {
    #     allow all;
    # }
}
EOF

ln -s /etc/nginx/sites-available/mythicaldash.conf /etc/nginx/sites-enabled/mythicaldash.conf

nginx -t
service nginx start

# Set up MariaDB database and user
MYSQL_ROOT_PASSWORD="changeme"
MYSQL_USER="mythicaldash"
MYSQL_PASSWORD="changeme"
MYSQL_DATABASE="mythicaldash"

export DEBIAN_FRONTEND=noninteractive

# Install mariadb-server without prompting for password
debconf-set-selections <<< "mariadb-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"



mysql -u root -e "CREATE DATABASE IF NOT EXISTS 
`$MYSQL_DATABASE`;"
mysql -u root -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON 
`$MYSQL_DATABASE`.* TO '$MYSQL_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Download MythicalDash from Git repository
cd /var/www/
git clone https://github.com/MythicalLTD/MythicalDash.git
cd mythicaldash

# Install PHP dependencies with Composer
composer install --no-interaction --optimize-autoloader

# Set up environment variables (replace with secure random strings later!)
cp .env.example .env
sed -i "s/APP_NAME=Laravel/APP_NAME=MythicalDash/g" .env
sed -i "s/APP_URL=http:\/\/localhost/APP_URL=http:\/\/your_ip_or_domain/g" .env
sed -i "s/DB_DATABASE=laravel/DB_DATABASE=$MYSQL_DATABASE/g" .env
sed -i "s/DB_USERNAME=root/DB_USERNAME=$MYSQL_USER/g" .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$MYSQL_PASSWORD/g" .env
sed -i "s/REDIS_HOST=127.0.0.1/REDIS_HOST=127.0.0.1/g" .env
sed -i "s/REDIS_PASSWORD=null/REDIS_PASSWORD=/g" .env

# Generate APP_KEY
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

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/mythicaldash
ExecStart=/usr/bin/php artisan queue:work --sleep=3 --tries=3
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mythicaldash-queue
systemctl start mythicaldash-queue


echo ""
echo "------------------------------------------------------------------"
echo "|                                                                |"
echo "|                 MythicalDash Installation Complete!                |"
echo "|                                                                |"
echo "------------------------------------------------------------------"
echo ""
echo "Next Steps:"
echo "1. Navigate to your server's IP address in a browser."
echo "2. Complete the setup process."
echo "3. Create your admin account."
echo ""
