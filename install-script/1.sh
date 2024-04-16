#!/bin/bash
set -ex

# Update and upgrade the system packages
sudo apt update
sudo apt upgrade -y

# Install Python 3.10 and necessary libraries
sudo apt install -y python3.10 python3.10-dev libpython3.10-dev python3.10-venv

# Install NVM and Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 21

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
sudo apt install -y nvidia-driver-550-server

if [[ -z "${KAMIWAZA_INSTALL_UNATTENDED}" ]]; then
    read -p "Please run sudo reboot for nvidia drivers;. Run script 2.sh after that."
else
    echo "Unattended install detected. Rebooting automatically..."
    sudo reboot
fi
