#!/bin/bash

# MythicalDash-v3 Installation Script

# Log file for commands
LOG_FILE="/var/log/mythicaldash_install.log"
touch "$LOG_FILE"

# Function to log commands and their output
log_command() {
    echo "Running: $*" | tee -a "$LOG_FILE"
    if "$@"; then
        echo "SUCCESS: $*" | tee -a "$LOG_FILE"
    else
        echo "ERROR: $* failed. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
        exit 1
    fi
}

echo "Starting MythicalDash-v3 installation..." | tee -a "$LOG_FILE"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect operating system. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Detected OS: $OS" | tee -a "$LOG_FILE"

# Ask for variables
read -p "Enter your database password for 'mythicaldash_remastered' user: " DB_PASSWORD
read -p "Enter your Panel URL (e.g., https://panel.example.com): " PANEL_URL
read -p "Enter your Panel API Key: " PANEL_API_KEY
read -p "Enter your MythicalDash instance URL (e.g., https://dash.example.com): " INSTANCE_URL
read -p "Enter your MythicalDash license key: " LICENSE_KEY
read -p "Enter your domain for Certbot (e.g., example.com): " DOMAIN
read -p "Enter your admin account email: " ADMIN_EMAIL

echo "Updating and upgrading system packages..." | tee -a "$LOG_FILE"
log_command apt update && apt upgrade -y

if [ "$OS" == "ubuntu" ]; then
    echo "Installing dependencies for Ubuntu..." | tee -a "$LOG_FILE"
    log_command apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
    log_command LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    log_command apt update
    [span_0](start_span)log_command apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis} mariadb-server nginx tar unzip zip git redis-server make dos2unix[span_0](end_span)
elif [ "$OS" == "debian" ]; then
    echo "Installing dependencies for Debian..." | tee -a "$LOG_FILE"
    [span_1](start_span)log_command apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release make[span_1](end_span)
    [span_2](start_span)echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list[span_2](end_span)
    [span_3](start_span)log_command curl -fsSL https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg[span_3](end_span)
    [span_4](start_span)log_command apt update[span_4](end_span)
    [span_5](start_span)log_command apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis}[span_5](end_span)
    echo "Attempting MariaDB installation via script..." | tee -a "$LOG_FILE"
    # This curl command has a pipe to sudo bash which should be handled carefully.
    # For automation, this is included as per the source.
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash || \
    [span_6](start_span)(echo "MariaDB repo setup failed, trying direct apt install." | tee -a "$LOG_FILE" && log_command apt install mariadb-client mariadb-server -y)[span_6](end_span)
    [span_7](start_span)log_command apt install -y mariadb-server nginx tar unzip git redis-server zip dos2unix[span_7](end_span)
else
    echo "Unsupported OS: $OS. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Installing NVM and Node.js 22..." | tee -a "$LOG_FILE"
log_command curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

log_command nvm install 22
log_command nvm use 22

echo "Installing Composer..." | tee -a "$LOG_FILE"
log_command curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

echo "Installing Yarn..." | tee -a "$LOG_FILE"
log_command npm i -g yarn

echo "Setting up MythicalDash-v3 directory..." | tee -a "$LOG_FILE"
log_command mkdir -p /var/www/mythicaldash-v3
log_command cd /var/www/mythicaldash-v3
log_command curl -Lo MythicalDash.zip https://github.com/MythicalLTD/MythicalDash/releases/latest/download/MythicalDash.zip
log_command unzip -o MythicalDash.zip -d /var/www/mythicaldash-v3

echo "Setting permissions..." | tee -a "$LOG_FILE"
log_command chown -R www-data:www-data /var/www/mythicaldash-v3/*

echo "Installing backend dependencies with Composer..." | tee -a "$LOG_FILE"
log_command cd /var/www/mythicaldash-v3/backend
log_command COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

echo "Configuring MariaDB..." | tee -a "$LOG_FILE"
log_command sudo sed -i '/^#collation-server/a collation-server = utf8mb4_general_ci' /etc/mysql/mariadb.conf.d/50-server.cnf
log_command sudo sed -i '/^character-set-server/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
log_command sudo sed -i '/^#character-set-server/a character-set-server = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
log_command sudo sed -i '/^character-set-collations/s/^/#/g' /etc/mysql/mariadb.conf.d/50-server.cnf
log_command sudo sed -i '/^#character-set-collations/a character-set-collations = utf8mb4' /etc/mysql/mariadb.conf.d/50-server.cnf
log_command systemctl restart mariadb

echo "Creating MariaDB user and database..." | tee -a "$LOG_FILE"
# Note: This requires manual password entry if running interactively.
# For automation, this part needs a secure way to pass the password.
# For this script, it assumes the user will manually enter the password or handle this part.
echo "Please enter the MariaDB root password when prompted:" | tee -a "$LOG_FILE"
log_command mariadb -u root -p <<EOF
[span_8](start_span)CREATE USER 'mythicaldash_remastered'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';[span_8](end_span)
[span_9](start_span)CREATE DATABASE mythicaldash_remastered;[span_9](end_span)
[span_10](start_span)GRANT ALL PRIVILEGES ON mythicaldash_remastered.* TO 'mythicaldash_remastered'@'127.0.0.1' WITH GRANT OPTION;[span_10](end_span)
FLUSH PRIVILEGES;
exit
EOF
echo "MariaDB user and database created successfully." | tee -a "$LOG_FILE"

echo "Running MythicalDash make commands..." | tee -a "$LOG_FILE"
log_command cd /var/www/mythicaldash-v3
log_command make set-prod
log_command make get-frontend

echo "Setting up Cron jobs..." | tee -a "$LOG_FILE"
(crontab -l 2>/dev/null; echo "* * * * * bash /var/www/mythicaldash-v3/backend/storage/cron/runner.bash >> /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/mythicaldash-v3/backend/storage/cron/runner.php >> /dev/null 2>&1") | crontab -

echo "Running MythicalDash setup and migration..." | tee -a "$LOG_FILE"
log_command php mythicaldash setup
log_command php mythicaldash migrate

echo "Configuring Pterodactyl settings..." | tee -a "$LOG_FILE"
# Interactive php commands, piping inputs
log_command php mythicaldash pterodactyl configure <<EOF
$PANEL_URL
$PANEL_API_KEY
y
EOF

echo "Configuring website settings..." | tee -a "$LOG_FILE"
# Interactive php commands, piping inputs
log_command php mythicaldash init <<EOF
$LICENSE_KEY
$INSTANCE_URL
EOF

echo "Installing Certbot..." | tee -a "$LOG_FILE"
[span_11](start_span)log_command sudo apt install -y certbot[span_11](end_span)
[span_12](start_span)log_command sudo apt install -y python3-certbot-nginx[span_12](end_span)

echo "Obtaining SSL certificate with Certbot for $DOMAIN..." | tee -a "$LOG_FILE"
log_command certbot certonly --nginx -d "$DOMAIN" || \
[span_13](start_span)(echo "Certbot Nginx plugin failed, trying standalone. Make sure to stop your webserver first if it prompts." | tee -a "$LOG_FILE" && log_command certbot certonly --standalone -d "$DOMAIN")[span_13](end_span)


echo "Setting up Certbot renewal cron job..." | tee -a "$LOG_FILE"
(crontab -l 2>/dev/null; echo "0 23 * * * certbot renew --quiet --deploy-hook \"systemctl restart nginx\"") | crontab -

echo "Configuring Nginx..." | tee -a "$LOG_FILE"
log_command rm -f /etc/nginx/sites-enabled/default

NGINX_CONF_PATH="/etc/nginx/sites-available/MythicalDashRemastered.conf"
echo "Creating Nginx configuration file at $NGINX_CONF_PATH" | tee -a "$LOG_FILE"
sudo bash -c "cat << 'EOF_NGINX' > $NGINX_CONF_PATH
server {
    listen 8089;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 8443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/mythicaldash-v3/frontend/dist;
    index index.html;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # [span_14](start_span)SSL Configuration -[span_14](end_span)
    [span_15](start_span)ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;[span_15](end_span)
    [span_16](start_span)ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;[span_16](end_span)
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    [span_17](start_span)ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";[span_17](end_span)
    [span_18](start_span)ssl_prefer_server_ciphers on;[span_18](end_span)

    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    [span_19](start_span)add_header X-Content-Type-Options nosniff;[span_19](end_span)
    [span_20](start_span)add_header X-XSS-Protection "1; mode=block";[span_20](end_span)
    [span_21](start_span)add_header X-Robots-Tag "index, follow";[span_21](end_span)
    [span_22](start_span)add_header Content-Security-Policy "frame-ancestors 'self'";[span_22](end_span)
    [span_23](start_span)add_header X-Frame-Options DENY;[span_23](end_span)
    [span_24](start_span)add_header Referrer-Policy same-origin;[span_24](end_span)
    [span_25](start_span)proxy_hide_header X-Powered-By;[span_25](end_span)
    [span_26](start_span)proxy_hide_header Server;[span_26](end_span)

    location / {
        [span_27](start_span)add_header X-Robots-Tag "index, follow";[span_27](end_span)
        [span_28](start_span)try_files \$uri \$uri/ /index.html;[span_28](end_span)
    }

    location /mc-admin {
        [span_29](start_span)add_header X-Robots-Tag "noindex, nofollow";[span_29](end_span)
        [span_30](start_span)try_files \$uri \$uri/ /index.html;[span_30](end_span)
    }

    location /api {
        [span_31](start_span)add_header X-Robots-Tag "noindex, nofollow";[span_31](end_span)
        [span_32](start_span)proxy_pass http://localhost:6000;[span_32](end_span)
        [span_33](start_span)proxy_set_header Host \$host;[span_33](end_span)
        [span_34](start_span)proxy_set_header X-Real-IP \$remote_addr;[span_34](end_span)
    }

    location /i/ {
        [span_35](start_span)add_header X-Robots-Tag "noindex, nofollow";[span_35](end_span)
        [span_36](start_span)proxy_pass http://localhost:6000;[span_36](end_span)
        [span_37](start_span)proxy_set_header Host \$host;[span_37](end_span)
        [span_38](start_span)proxy_set_header X-Real-IP \$remote_addr;[span_38](end_span)
        [span_39](start_span)proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;[span_39](end_span)
        [span_40](start_span)proxy_set_header X-Forwarded-Proto \$scheme;[span_40](end_span)
    }

    location /attachments {
        [span_41](start_span)alias /var/www/mythicaldash-v3/backend/public/attachments;[span_41](end_span)
    }

}

server {
    listen 6000;
    server_name localhost;
    root /var/www/mythicaldash-v3/backend/public;

    [span_42](start_span)index index.php;[span_42](end_span)
    # allow larger file uploads and longer script runtimes
    [span_43](start_span)client_max_body_size 100m;[span_43](end_span)
    [span_44](start_span)client_body_timeout 120s;[span_44](end_span)

    [span_45](start_span)sendfile off;[span_45](end_span)
    [span_46](start_span)error_log /var/www/mythicaldash-v3/backend/storage/logs/mythicaldash-v3.log error;[span_46](end_span)

    location / {
        [span_47](start_span)proxy_set_header Host \$host;[span_47](end_span)
        [span_48](start_span)proxy_set_header X-Real-IP \$remote_addr;[span_48](end_span)
        [span_49](start_span)proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;[span_49](end_span)
        [span_50](start_span)proxy_set_header X-Forwarded-Proto \$scheme;[span_50](end_span)
        [span_51](start_span)proxy_hide_header X-Powered-By;[span_51](end_span)
        [span_52](start_span)proxy_hide_header Server;[span_52](end_span)
        [span_53](start_span)add_header Server "MythicalDash";[span_53](end_span)
        [span_54](start_span)try_files \$uri \$uri/ /index.php?\$query_string;[span_54](end_span)
    }

    location ~ \\.php\$ {
        [span_55](start_span)fastcgi_split_path_info ^(.+\\.php)(/.+)\$;[span_55](end_span)
        [span_56](start_span)fastcgi_pass unix:/run/php/php8.3-fpm.sock;[span_56](end_span)
        [span_57](start_span)fastcgi_index index.php;[span_57](end_span)
        [span_58](start_span)include fastcgi_params;[span_58](end_span)
        [span_59](start_span)fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";[span_59](end_span)
        [span_60](start_span)fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;[span_60](end_span)
        [span_61](start_span)fastcgi_param HTTP_PROXY "";[span_61](end_span)
        [span_62](start_span)fastcgi_intercept_errors off;[span_62](end_span)
        [span_63](start_span)fastcgi_buffer_size 16k;[span_63](end_span)
        [span_64](start_span)fastcgi_buffers 4 16k;[span_64](end_span)
        [span_65](start_span)fastcgi_connect_timeout 300;[span_65](end_span)
        [span_66](start_span)fastcgi_send_timeout 300;[span_66](end_span)
        [span_67](start_span)fastcgi_read_timeout 300;[span_67](end_span)
        [span_68](start_span)include /etc/nginx/fastcgi_params;[span_68](end_span)
    }

    location ~ /\\.ht {
        [span_69](start_span)deny all;[span_69](end_span)
    }
}
EOF_NGINX"

log_command sudo ln -s "$NGINX_CONF_PATH" /etc/nginx/sites-enabled/MythicalDashRemastered.conf
log_command service nginx restart

echo "Creating admin user..." | tee -a "$LOG_FILE"
# Interactive php commands, piping inputs
log_command php mythicaldash makeAdmin <<EOF
$ADMIN_EMAIL
EOF

echo "Setting final permissions..." | tee -a "$LOG_FILE"
log_command chown -R www-data:www-data /var/www/mythicaldash-v3/*

echo "MythicalDash-v3 installation complete!" | tee -a "$LOG_FILE"
echo "Please navigate to your instance URL: $INSTANCE_URL" | tee -a "$LOG_FILE"

