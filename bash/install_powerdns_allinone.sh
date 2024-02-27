#!/bin/bash

# Variables
repo_url="https://raw.githubusercontent.com/vanAmsen/automation/main/bash"

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Array of script names
scripts=("install_powerdns.sh" "install_powerdns_admin.sh" "install_powerdns_ngnix.sh" "install_powerdns_api.sh")

# Function to download and execute each script
execute_script() {
    script_name=$1
    wget "${repo_url}/${script_name}" -O "${script_name}"
    chmod +x "${script_name}"
    ./"${script_name}"
}

# Download and execute each script in order
for script in "${scripts[@]}"; do
    echo "Installing ${script}..."
    execute_script "${script}"
    if [ $? -ne 0 ]; then
        echo "Installation of ${script} failed."
        exit 1
    fi
    echo -e "${GREEN}${script} installed successfully.${NC}"

    # Pause for user input after installing PowerDNS Admin
    if [[ "${script}" == "install_powerdns_admin.sh" ]]; then
        read -p "Press [Enter] to continue with the next installation..."
    fi
done

echo "All installations completed successfully."
