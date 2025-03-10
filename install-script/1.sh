#!/bin/bash
set -ex
# Update and upgrade the system packages

sudo apt update
export DEBIAN_FRONTEND=noninteractive
sudo apt upgrade -y

# Install Python 3.10 and necessary libraries
sudo apt install -y python3.10 python3.10-dev libpython3.10-dev python3.10-venv golang-cfssl python-is-python3 etcd-client net-tools jq

# This is now done by install.sh - leaving temporarily in memoriam
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# 9nvm install 21
# Install Docker and Docker Compose
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install CockroachDB and other dependencies
wget -qO- https://binaries.cockroachdb.com/cockroach-v23.1.17.linux-amd64.tgz | tar xvz
sudo cp cockroach-v23.1.17.linux-amd64/cockroach /usr/local/bin
sudo apt install -y libcairo2-dev libgirepository1.0-dev
sudo apt update

# Install NVIDIA drivers
# Add the NVIDIA graphics-drivers PPA for latest drivers
sudo add-apt-repository -y ppa:graphics-drivers/ppa
sudo apt update

# First, check if ubuntu-drivers utility is available, install if not
if ! command -v ubuntu-drivers &> /dev/null; then
    echo "Installing ubuntu-drivers-common..."
    sudo apt install -y ubuntu-drivers-common
fi

# Get the recommended driver version from ubuntu-drivers
echo "Checking recommended NVIDIA driver..."
RECOMMENDED_DRIVER=""
if command -v ubuntu-drivers &> /dev/null; then
    # Get just the version number of the recommended driver
    RECOMMENDED_DRIVER=$(ubuntu-drivers devices 2>/dev/null | grep "nvidia-driver-" | grep "recommended" | grep -o -E 'nvidia-driver-[0-9]+' | head -n 1 | cut -d'-' -f3)
    echo "Ubuntu recommends driver version: $RECOMMENDED_DRIVER"
fi

# If recommended driver is empty or less than 550, install 550
if [ -z "$RECOMMENDED_DRIVER" ] || [ "$RECOMMENDED_DRIVER" -lt 550 ]; then
    echo "Recommended driver ($RECOMMENDED_DRIVER) is below 550 or not found, installing nvidia-driver-550-server..."
    sudo apt install -y nvidia-driver-550-server
else
    # Install the specific detected recommended driver instead of using ubuntu-drivers install
    echo "Installing explicitly recommended driver version: nvidia-driver-${RECOMMENDED_DRIVER}..."
    sudo apt install -y "nvidia-driver-${RECOMMENDED_DRIVER}-server"
    
    # Check if any NVIDIA driver was actually installed
    if ! dpkg -l | grep -q "nvidia-driver-"; then
        echo "No NVIDIA driver was installed, falling back to nvidia-driver-550-server..."
        sudo apt install -y nvidia-driver-550-server
    fi
fi

if [[ -z "${KAMIWAZA_INSTALL_UNATTENDED}" ]]; then
    read -p "Please run sudo reboot for nvidia drivers. Run script 2.sh after that."
else
    echo "Unattended install detected. Rebooting automatically..."
    sudo reboot
fi