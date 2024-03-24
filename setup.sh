#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker could not be found. Please install Docker from https://docs.docker.com/get-docker/"
    exit 1
else
    echo "Docker is installed."
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "Docker is not running. Attempting to start Docker..."
        sudo systemctl start docker
        if ! docker info &> /dev/null; then
            echo "Failed to start Docker. Please start Docker manually."
            exit 1
        else
            echo "Docker started successfully."
        fi
    else
        echo "Docker is already running."
    fi
fi

# Check if DDEV is installed
if ! command -v ddev &> /dev/null; then
    echo "DDEV could not be found. Please install DDEV by following the instructions at https://ddev.readthedocs.io/en/stable/#installation"
    exit 1
else
    echo "DDEV is installed."
fi

# Check mkcert is installed
if ! command -v mkcert &> /dev/null; then
    echo "mkcert is not installed. Please install mkcert."
    exit 1
else
    echo "mkcert is installed."
fi

# Prompt for the new site name
read -p "Enter the new site name: " site_name

# Inform user about .ddev.site for local development
site_name=${site_name//.co.uk/}
site_name=${site_name//.com/}

echo "Note: For local development, .ddev.site will be used."

# Validate modified site name
if [[ ! $site_name =~ ^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*)*$ ]]; then
    echo "Error: Site name must consist of lowercase letters, dashes, and dots only."
    exit 1
fi

# Update .ddev/config.yaml with the new site name
sed -i'' -e "s/^name:.*/name: $site_name/" .ddev/config.yaml
echo "The .ddev/config.yaml file has been updated with the new site name: $site_name"

# Generate and set WordPress security keys
AUTH_KEY=$(openssl rand -base64 40)
SECURE_AUTH_KEY=$(openssl rand -base64 40)
LOGGED_IN_KEY=$(openssl rand -base64 40)
NONCE_KEY=$(openssl rand -base64 40)
AUTH_SALT=$(openssl rand -base64 40)
SECURE_AUTH_SALT=$(openssl rand -base64 40)
LOGGED_IN_SALT=$(openssl rand -base64 40)
NONCE_SALT=$(openssl rand -base64 40)

# Assuming WP_HOME uses .ddev.site for local development
WP_HOME="https://${site_name}.ddev.site"

# Create the .env file
echo "Creating .env file..."
cat <<EOF > .env
DB_NAME=db
DB_USER=db
DB_PASSWORD=db
DB_HOST=db
DB_PREFIX='wp_'

WP_ENV=production
WP_HOME=$WP_HOME
WP_SITEURL=\${WP_HOME}/wp

AUTH_KEY='$AUTH_KEY'
SECURE_AUTH_KEY='$SECURE_AUTH_KEY'
LOGGED_IN_KEY='$LOGGED_IN_KEY'
NONCE_KEY='$NONCE_KEY'
AUTH_SALT='$AUTH_SALT'
SECURE_AUTH_SALT='$SECURE_AUTH_SALT'
LOGGED_IN_SALT='$LOGGED_IN_SALT'
NONCE_SALT='$NONCE_SALT'

DISABLE_WP_CRON=true
WPLANG=en_GB
WP_DEBUG=true
WP_DEBUG_LOG=true
WP_DEBUG_DISPLAY=false
EOF

echo ".env file has been created at $(pwd)/.env"

# Prompt for theme name
read -p "Enter the theme name [PixelCodeLab]: " theme_name
theme_name=${theme_name:-PixelCodeLab}

# Run composer install to set up WordPress
composer install || { echo "Composer install failed. Exiting."; exit 1; }

# Check for NVM and install required Node.js version
echo "Checking for NVM and installing the required version of Node.js..."
if ! command -v nvm &> /dev/null; then
    echo "NVM is not installed. Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    echo "NVM installed successfully."
fi

# Install and use the required Node.js version
nvm install 20.11.1
nvm use 20.11.1
echo "Node.js version 20.11.1 has been installed."

# Navigate to theme directory and setup
cd web/app/themes || exit 1
if [ -d "$theme_name" ]; then
    echo "Theme directory exists."
else
    if [ -d "PixelCodeLab" ]; then
        mv "PixelCodeLab" "$theme_name"
        echo "Theme directory renamed to $theme_name."
    else
        echo "Default theme directory not found. Please check the theme name."
        exit 1
    fi
fi
cd "$theme_name" || exit 1
npm install || { echo "npm install failed. Exiting."; exit 1; }

# Return to the project root directory
cd ../../../..

# Start DDEV
echo "Starting DDEV..."
ddev start || { echo "Failed to start DDEV. Please check your DDEV setup. Exiting."; exit 1; }

echo "Setup complete. DDEV project started."
echo "Your project is now available at $WP_HOME."
echo "Your theme has been set to: $theme_name."
echo "To further develop your theme, navigate to 'web/app/themes/$theme_name'."

# Optionally, offer to open the project in Visual Studio Code
read -p "Would you like to open this project in Visual Studio Code now? (y/N): " open_vscode
if [[ $open_vscode =~ ^[Yy]$ ]]; then
    if command -v code &> /dev/null; then
        code .
    else
        echo "Visual Studio Code command 'code' not found. Please open the project manually."
    fi
fi
