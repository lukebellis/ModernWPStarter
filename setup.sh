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
fi
echo "DDEV is installed."

# Prompt for the new site name
read -p "Enter the new site name: " site_name

# Inform user about .ddev.site for local development
if [[ $site_name =~ \.co\.uk$|\.com$ ]]; then
    echo "Note: For local development, .ddev.site will be used. The provided domain extension will be removed."
    site_name="${site_name%.*}"
    site_name="${site_name%.*}"
fi

# Validate modified site name
if [[ ! $site_name =~ ^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*)*$ ]]; then
    echo "Error: Site name must consist of lowercase letters, dashes, and dots only."
    exit 1
fi

# Rename the project directory to match the new site name
current_dir=$(basename "$(pwd)")
parent_dir=$(dirname "$(pwd)")
if [ "$current_dir" != "$site_name" ]; then
    cd "$parent_dir"
    if mv "$current_dir" "$site_name"; then
        echo "Directory has been renamed to $site_name."
        cd "$site_name"
    else
        echo "Failed to rename the directory. Please check your permissions."
        exit 1
    fi
else
    echo "The directory name already matches the site name."
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

# Explicitly create the .env file and then append the configuration
touch .env
{
    echo "DB_NAME=db"
    echo "DB_USER=db"
    echo "DB_PASSWORD=db"
    echo "DB_HOST=db"
    echo "DB_PREFIX='wp_'"
    echo ""
    echo "WP_ENV=production"
    echo "WP_HOME=$WP_HOME"
    echo "WP_SITEURL=\${WP_HOME}/wp"
    echo ""
    echo "AUTH_KEY='$AUTH_KEY'"
    echo "SECURE_AUTH_KEY='$SECURE_AUTH_KEY'"
    echo "LOGGED_IN_KEY='$LOGGED_IN_KEY'"
    echo "NONCE_KEY='$NONCE_KEY'"
    echo "AUTH_SALT='$AUTH_SALT'"
    echo "SECURE_AUTH_SALT='$SECURE_AUTH_SALT'"
    echo "LOGGED_IN_SALT='$LOGGED_IN_SALT'"
    echo "NONCE_SALT='$NONCE_SALT'"
    echo ""
    echo "DISABLE_WP_CRON=true"
    echo "WPLANG=en_GB"
    echo "WP_DEBUG=true"
    echo "WP_DEBUG_LOG=true"
    echo "WP_DEBUG_DISPLAY=false"
} > .env

echo ".env file has been created at $(pwd)/.env"

# Prompt for theme name
cd web/app/themes ||
exit 1
read -p "Enter the theme name [PixelCodeLab]: " theme_name
theme_name=${theme_name:-PixelCodeLab}

# If a theme directory with the default name exists, rename it
if [ -d "PixelCodeLab" ]; then
    mv PixelCodeLab "$theme_name"
fi
cd "$theme_name" || exit 1
echo "Theme directory set to: $theme_name"

# Inform user about manual actions if Docker or Node.js versions need to be managed
echo "Checking for NVM and installing the required version of Node.js."

# Install NVM and Node.js version 20.11.1 if NVM is not installed
if ! command -v nvm &> /dev/null; then
    echo "NVM is not installed. Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    echo "NVM installed successfully."
fi

echo "Installing Node.js version 20.11.1."
nvm install 20.11.1 || exit 1

npm install || exit 1

# Return to the root directory and start DDEV
cd ../../.. || exit 1
echo "Starting DDEV..."
ddev start || exit 1

echo "Setup complete. DDEV project started."
echo "Your project is now available at $WP_HOME"
echo "Your theme has been set to: $theme_name"

# Ensure Docker is started
if ! docker info &> /dev/null; then
    echo "Attempting to start Docker..."
    sudo service docker start
    if ! docker info &> /dev/null; then
        echo "Failed to start Docker. Please start Docker manually."
        exit 1
    else
        echo "Docker started successfully."
    fi
fi
