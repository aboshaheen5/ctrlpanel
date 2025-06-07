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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# Main menu function
show_main_menu() {
    echo -e "${YELLOW}=== Pterodactyl Client Area Management ===${NC}"
    echo -e "${YELLOW}Please select an option:${NC}"
    echo "1. Install new client area"
    echo "2. Update existing installation"
    echo "3. Change domain name"
    echo "4. Uninstall client area"
    echo "5. Exit"
    
    choice=$(get_input "Enter your choice (1-5)")
    
    case $choice in
        1)
            if [ -f "/var/www/ctrlpanel/.installed_by_script" ]; then
                print_error "An installation already exists. Please use the update option instead."
                exit 1
            fi
            perform_installation
            ;;
        2)
            if [ ! -f "/var/www/ctrlpanel/.installed_by_script" ]; then
                print_error "No installation found. Please install first."
                exit 1
            fi
            perform_update
            ;;
        3)
            if [ ! -f "/var/www/ctrlpanel/.installed_by_script" ]; then
                print_error "No installation found. Please install first."
                exit 1
            fi
            change_domain
            ;;
        4)
            if [ ! -f "/var/www/ctrlpanel/.installed_by_script" ]; then
                print_error "No installation found."
                exit 1
            fi
            uninstall
            ;;
        5)
            print_status "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Function to perform installation
perform_installation() {
    echo -e "${YELLOW}=== Pterodactyl Client Area Installation ===${NC}"
    echo -e "${YELLOW}Please provide the following information:${NC}"
    
    DOMAIN=$(get_input "Enter your domain name (e.g., example.com)")
    
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

    # Install Redis
    print_status "Installing Redis..."
    apt install -y redis-server
    systemctl enable redis-server
    systemctl start redis-server

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
    rm -rf /var/www/ctrlpanel
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel

    # Clone the ready-made client area
    print_status "Cloning the client area..."
    git clone https://github.com/ControlPanel-gg/dashboard.git .

    # Update composer.json to fix package issues
    print_status "Updating composer.json..."
    sed -i 's/"biscollab\/laravel-recaptcha": "^1.0"/"biscollab\/laravel-recaptcha": "^1.0",\n        "paypal\/paypal-server-sdk": "^1.0"/g' composer.json

    # Install dependencies
    print_status "Installing PHP dependencies..."
    echo -e "${YELLOW}This step may take a few minutes. Please wait...${NC}"
    composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

    if [ $? -eq 0 ]; then
        print_success "PHP dependencies installed successfully!"
    else
        print_error "Failed to install PHP dependencies"
        exit 1
    fi

    # Set proper permissions
    print_status "Setting proper permissions..."
    chown -R www-data:www-data /var/www/ctrlpanel
    chmod -R 755 /var/www/ctrlpanel
    chmod -R 777 /var/www/ctrlpanel/storage
    chmod -R 777 /var/www/ctrlpanel/bootstrap/cache

    # Configure Nginx
    print_status "Configuring Nginx..."
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    cat > /etc/nginx/sites-available/pterodactyl.conf << 'EOL'
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/ctrlpanel/public;

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
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
    certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}

    # Restart services
    print_status "Restarting services..."
    systemctl restart nginx
    systemctl restart php8.2-fpm
    systemctl restart redis-server

    # Create installation marker
    touch /var/www/ctrlpanel/.installed_by_script

    # Installation complete
    echo -e "\n${GREEN}=== Installation Completed Successfully! ===${NC}"
    echo -e "${YELLOW}Your client area is now ready to use!${NC}"
    echo -e "${GREEN}Access your client area at: https://${DOMAIN}${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Visit https://${DOMAIN} to complete the installation"
    echo "2. Follow the installation wizard to set up your database and admin account"
    echo -e "\n${GREEN}Thank you for using Pterodactyl Client Area!${NC}"
}

# Function to perform update
perform_update() {
    print_status "Starting update process..."
    cd /var/www/ctrlpanel
    
    # Backup current .env file
    if [ -f ".env" ]; then
        cp .env .env.backup
    fi
    
    # Pull latest changes
    git pull origin main
    
    # Update dependencies
    composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs
    
    # Restore .env file
    if [ -f ".env.backup" ]; then
        mv .env.backup .env
    fi
    
    # Clear cache and optimize
    php artisan optimize:clear
    php artisan optimize
    
    # Update permissions
    chown -R www-data:www-data /var/www/ctrlpanel
    chmod -R 755 /var/www/ctrlpanel
    chmod -R 777 /var/www/ctrlpanel/storage
    chmod -R 777 /var/www/ctrlpanel/bootstrap/cache
    
    # Restart services
    systemctl restart nginx
    systemctl restart php8.2-fpm
    
    print_success "Update completed successfully!"
}

# Function to change domain
change_domain() {
    print_status "Changing domain name..."
    
    # Get new domain
    NEW_DOMAIN=$(get_input "Enter new domain name (e.g., example.com)")
    
    # Update Nginx configuration
    sed -i "s/server_name .*;/server_name ${NEW_DOMAIN};/" /etc/nginx/sites-available/pterodactyl.conf
    
    # Update SSL certificate
    certbot --nginx -d ${NEW_DOMAIN} --non-interactive --agree-tos --email admin@${NEW_DOMAIN}
    
    # Restart Nginx
    systemctl restart nginx
    
    print_success "Domain changed successfully to ${NEW_DOMAIN}"
}

# Function to uninstall
uninstall() {
    print_status "Uninstalling client area..."
    
    # Confirm uninstallation
    echo -e "${RED}WARNING: This will remove the client area and all its data.${NC}"
    confirm=$(get_input "Are you sure you want to continue? (yes/no)")
    
    if [ "$confirm" != "yes" ]; then
        print_status "Uninstallation cancelled."
        exit 0
    fi
    
    # Remove installation directory
    rm -rf /var/www/ctrlpanel
    
    # Remove Nginx configuration
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    
    # Restart Nginx
    systemctl restart nginx
    
    print_success "Client area uninstalled successfully!"
}

# Show main menu
show_main_menu 