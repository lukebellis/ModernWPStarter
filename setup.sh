#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found. Please install Docker from https://docs.docker.com/get-docker/"
    exit 1
fi

echo "Docker is installed."

# Check if DDEV is installed
if ! command -v ddev &> /dev/null
then
    echo "DDEV could not be found. Please install DDEV by following the instructions at https://ddev.readthedocs.io/en/stable/#installation"
    exit 1
fi

echo "DDEV is installed."

# Prompt for the new site name
read -p "Enter the new site name (lowercase only): " site_name

# Validate site name
if [[ ! $site_name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: Site name must be lowercase letters and dashes only."
  exit 1
fi

# Update .ddev/config.yaml with the new site name
sed -i'' -e "s/^name:.*/name: $site_name/" .ddev/config.yaml

echo "The .ddev/config.yaml file has been updated with the new site name."

# Inform user about manual actions if Docker or Node.js versions need to be managed
echo "Please manually ensure the required version of Node.js is installed."

# Composer and npm setup
composer update && composer install || exit 1
cd web/app/themes/PCL || exit 1

# Assuming NVM is used for managing Node.js versions
if ! command -v nvm &> /dev/null
then
    echo "NVM is not installed. Please install NVM from https://github.com/nvm-sh/nvm#installing-and-updating"
else
    nvm install 20.11.1 || exit 1
fi

npm install || exit 1

# Return to the root directory and start DDEV
cd - || exit 1
ddev start || exit 1

echo "Setup complete. DDEV project started."
