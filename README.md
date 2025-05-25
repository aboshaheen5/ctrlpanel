# Pterodactyl Client Area Installer

A professional installation script for setting up a ready-to-use Pterodactyl client area. This script automates the entire installation process, making it easy to deploy a fully functional client area for your Pterodactyl panel.

## Features

- 🚀 One-click installation
- 🔒 Secure by default
- 🎨 Beautiful and modern UI
- 🌐 Multi-language support
- 💳 Built-in billing system
- 🎫 Ticket system
- 👥 User management
- 📊 Server statistics
- 🔄 Automatic updates
- 🛡️ Security features

## Requirements

- Ubuntu/Debian based system
- PHP 8.1 or higher
- MySQL/MariaDB
- Nginx
- Root access

## Quick Installation

1. Clone the repository:
```bash
git clone https://github.com/aboshaheen5/pterodactyl-client-area.git
cd pterodactyl-client-area
```

2. Make the script executable:
```bash
chmod +x install.sh
```

3. Run the installation script:
```bash
sudo ./install.sh
```

## Post-Installation

After the installation is complete, you need to:

1. Update your domain name in the Nginx configuration
2. Configure your database settings in the `.env` file
3. Create an admin account using:
```bash
php artisan make:admin
```

## Configuration

### Environment Variables

Edit the `.env` file to configure your installation:

```env
APP_NAME="Your Client Area Name"
APP_URL="https://your-domain.com"
DB_HOST=localhost
DB_DATABASE=your_database
DB_USERNAME=your_username
DB_PASSWORD=your_password
```

### Nginx Configuration

The script automatically creates an Nginx configuration file at `/etc/nginx/sites-available/pterodactyl.conf`. Make sure to update the `server_name` directive with your domain name.

## Security

The installation script implements several security measures:

- Secure file permissions
- PHP-FPM configuration
- Nginx security headers
- CSRF protection
- XSS protection

## Support

If you need help or have questions:

- Open an issue on GitHub
- Join our Discord server
- Check the documentation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

- **Abdelrahman Shaheen** - [aboshaheen5](https://github.com/aboshaheen5)

## Acknowledgments

- [ControlPanel-gg](https://github.com/ControlPanel-gg/dashboard) for the base client area
- [Pterodactyl](https://pterodactyl.io/) for the game panel
- All contributors and users of this project

## Donate

If you find this project helpful, consider supporting its development:

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/aboshaheen553)

---

Made with ❤️ by [aboshaheen5](https://github.com/aboshaheen5) 