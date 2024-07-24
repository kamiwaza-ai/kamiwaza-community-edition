# Add the NVIDIA Docker repository and install the NVIDIA container toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt-get install -y nvidia-container-toolkit
sudo apt install -y nvidia-docker2
sudo systemctl restart docker
sudo usermod -aG docker $USER

# Check if docker group is applied
if groups | grep -q '\bdocker\b'; then
    echo "Docker group is applied already."
    if [[ -z "${KAMIWAZA_INSTALL_UNATTENDED}" ]]; then
        echo "Please run script 3.sh to continue the installation."
    else
        echo "Unattended mode, running 3.sh..."
        ./3.sh
    fi
else
    if [[ -z "${KAMIWAZA_INSTALL_UNATTENDED}" ]]; then
        echo "Docker group not applied. Please log out and log back in, then run script 3.sh."
    else
        echo "Unattended mode, running 3.sh with sudo..."
        sudo -g docker ./3.sh
    fi
fi