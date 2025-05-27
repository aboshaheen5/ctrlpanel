#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# Function to get user input
get_input() {
    read -p "$1: " input
    echo $input
}

# Function to install dependencies
install_dependencies() {
    print_message "Installing dependencies..."
    
    # Add PHP repository
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    
    # Add Redis repository
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    
    # Add MariaDB repository
    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
    
    # Update repositories
    apt update
    
    # Install PHP and other dependencies
    apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} mariadb-server nginx git redis-server
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    
    # Enable Redis
    systemctl enable --now redis-server
}

# Function to setup database
setup_database() {
    print_message "Setting up database..."
    
    # Get database credentials from user
    DB_USER=$(get_input "Enter database username")
    DB_PASS=$(get_input "Enter database password")
    DB_NAME="ctrlpanel"
    
    # Create database and user
    mysql -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
    mysql -e "CREATE DATABASE ${DB_NAME};"
    mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Save database credentials to .env file
    echo "DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}" > /var/www/ctrlpanel/.env
}

# Function to setup CtrlPanel
setup_ctrlpanel() {
    print_message "Setting up CtrlPanel..."
    
    # Create directory and clone repository
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel
    git clone https://github.com/Ctrlpanel-gg/panel.git ./
    
    # Install composer packages
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    
    # Create storage symlink
    php artisan storage:link
    
    # Set permissions
    chown -R www-data:www-data /var/www/ctrlpanel/
    chmod -R 755 storage/* bootstrap/cache/
}

# Function to setup queue worker
setup_queue_worker() {
    print_message "Setting up queue worker..."
    
    # Create systemd service file
    cat > /etc/systemd/system/ctrlpanel.service << EOL
[Unit]
Description=Ctrlpanel Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOL
    
    # Enable and start service
    systemctl enable --now ctrlpanel.service
    
    # Setup crontab
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/ctrlpanel/artisan schedule:run >> /dev/null 2>&1") | crontab -
}

# Main installation process
main() {
    print_message "Starting CtrlPanel installation..."
    
    # Install dependencies
    install_dependencies
    
    # Setup database
    setup_database
    
    # Setup CtrlPanel
    setup_ctrlpanel
    
    # Setup queue worker
    setup_queue_worker
    
    print_message "Installation completed! Please visit https://YOUR_DOMAIN/installer to complete the setup."
}

# Run main function
main 