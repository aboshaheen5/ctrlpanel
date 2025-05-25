#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_error() {
    echo -e "${RED}[-] $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get user input
get_input() {
    read -p "$1: " input
    echo $input
}

# Function to get password input (hidden)
get_password() {
    read -sp "$1: " input
    echo
    echo $input
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# Get required information
echo -e "${YELLOW}=== Pterodactyl Client Area Installation ===${NC}"
echo -e "${YELLOW}Please provide the following information:${NC}"

DOMAIN=$(get_input "Enter your domain name (e.g., example.com)")
DB_NAME=$(get_input "Enter database name (default: pterodactyl)")
DB_NAME=${DB_NAME:-pterodactyl}
DB_USER=$(get_input "Enter database username (default: pterodactyl)")
DB_USER=${DB_USER:-pterodactyl}
DB_PASS=$(get_password "Enter database password")
ADMIN_EMAIL=$(get_input "Enter admin email")
ADMIN_USERNAME=$(get_input "Enter admin username")
ADMIN_PASSWORD=$(get_password "Enter admin password")

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install required dependencies
print_status "Installing required dependencies..."
apt install -y software-properties-common apt-transport-https lsb-release ca-certificates gnupg2 curl git

# Add PHP repository
print_status "Adding PHP repository..."
add-apt-repository -y ppa:ondrej/php
apt update

# Remove PHP 8.1 if exists
print_status "Removing PHP 8.1 if exists..."
apt remove -y php8.1-fpm php8.1-cli php8.1-common php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath php8.1-intl php8.1-ldap php8.1-imap php8.1-soap php8.1-pspell php8.1-phpdbg php8.1-sqlite3 php8.1-memcached php8.1-redis php8.1-xdebug php8.1-opcache php8.1-readline php8.1-xmlrpc php8.1-gmp php8.1-imagick php8.1-dev

# Install PHP 8.2 and extensions
print_status "Installing PHP 8.2 and extensions..."
apt install -y php8.2-fpm php8.2-cli php8.2-common php8.2-mysql php8.2-zip php8.2-gd php8.2-mbstring php8.2-curl php8.2-xml php8.2-bcmath php8.2-intl php8.2-ldap php8.2-imap php8.2-soap php8.2-pspell php8.2-phpdbg php8.2-sqlite3 php8.2-memcached php8.2-redis php8.2-xdebug php8.2-opcache php8.2-readline php8.2-xmlrpc php8.2-gmp php8.2-imagick php8.2-dev

# Verify PHP installation
if ! command_exists php; then
    print_error "PHP installation failed"
    exit 1
fi

# Install MySQL
print_status "Installing MySQL..."
apt install -y mysql-server

# Verify MySQL installation
if ! command_exists mysql; then
    print_error "MySQL installation failed"
    exit 1
fi

# Install Nginx
print_status "Installing Nginx..."
apt install -y nginx

# Verify Nginx installation
if ! command_exists nginx; then
    print_error "Nginx installation failed"
    exit 1
fi

# Install Composer
print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Verify Composer installation
if ! command_exists composer; then
    print_error "Composer installation failed"
    exit 1
fi

# Create directory for the client area
print_status "Creating installation directory..."
rm -rf /var/www/pterodactyl
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

# Clone the ready-made client area
print_status "Cloning the client area..."
git clone https://github.com/ControlPanel-gg/dashboard.git .

# Install dependencies
print_status "Installing PHP dependencies..."
echo -e "${YELLOW}This step may take a few minutes. Please wait...${NC}"
composer install --no-dev --optimize-autoloader --no-interaction

if [ $? -eq 0 ]; then
    print_success "PHP dependencies installed successfully!"
else
    print_error "Failed to install PHP dependencies"
    exit 1
fi

# Create database and user
print_status "Creating database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Configure .env file
print_status "Configuring environment..."
cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

# Set proper permissions
print_status "Setting proper permissions..."
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl
chmod -R 777 /var/www/pterodactyl/storage
chmod -R 777 /var/www/pterodactyl/bootstrap/cache

# Configure Nginx
print_status "Configuring Nginx..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

cat > /etc/nginx/sites-available/pterodactyl.conf << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/pterodactyl/public;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOL

# Enable the site
ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure firewall
print_status "Configuring firewall..."
if command_exists ufw; then
    ufw allow 80
    ufw allow 443
    ufw allow 22
    ufw --force enable
fi

# Install SSL certificate
print_status "Installing SSL certificate..."
apt install -y certbot python3-certbot-nginx
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${ADMIN_EMAIL}

# Restart services
print_status "Restarting services..."
systemctl restart nginx
systemctl restart php8.2-fpm

# Generate application key
print_status "Generating application key..."
php artisan key:generate

# Run database migrations
print_status "Running database migrations..."
php artisan migrate --force

# Create admin user
print_status "Creating admin user..."
php artisan make:admin --email="${ADMIN_EMAIL}" --username="${ADMIN_USERNAME}" --password="${ADMIN_PASSWORD}"

# Clear cache and optimize
print_status "Optimizing application..."
php artisan config:clear
php artisan cache:clear
php artisan view:clear
php artisan route:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Installation complete
echo -e "\n${GREEN}=== Installation Completed Successfully! ===${NC}"
echo -e "${YELLOW}Your client area is now ready to use!${NC}"
echo -e "${GREEN}Access your client area at: https://${DOMAIN}${NC}"
echo -e "\n${YELLOW}Admin credentials:${NC}"
echo "Email: ${ADMIN_EMAIL}"
echo "Username: ${ADMIN_USERNAME}"
echo -e "\n${GREEN}Please save these credentials in a secure place!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Set up your payment gateway"
echo "2. Configure your email settings"
echo -e "\n${GREEN}Thank you for using Pterodactyl Client Area!${NC}" 