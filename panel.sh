#!/bin/bash

echo "[🔄] Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "[🌐] Installing dependencies..."
sudo apt install curl wget git zip unzip software-properties-common gnupg2 ca-certificates lsb-release -y

echo "[🐘] Adding PHP 8.2 repository..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

echo "[📦] Installing PHP 8.2 and extensions..."
sudo apt install php8.2 php8.2-fpm php8.2-cli php8.2-mysql php8.2-curl php8.2-mbstring php8.2-xml php8.2-zip php8.2-bcmath php8.2-gd php8.2-common php8.2-readline -y

echo "[🧶] Installing NVM (Node Version Manager)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

echo "[⬇️] Installing Node.js v22..."
nvm install 22
nvm use 22
nvm alias default 22

echo "[📦] Installing Yarn globally..."
npm install -g yarn

echo "[📁] Cloning MythicalDash repo..."
git clone https://github.com/NIRAVDEV/panel.git panel
cd panel || exit

echo "[⚙️] Installing frontend dependencies..."
cd frontend || exit
yarn install
cd ..

echo "[⚙️] Installing backend dependencies..."
cd backend || exit
composer install || curl -sS https://getcomposer.org/installer | php && php composer.phar install
cd ..

echo "[✅] Setup Complete!"
