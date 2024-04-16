
# Add the NVIDIA Docker repository and install the NVIDIA container toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt-get install -y nvidia-container-toolkit
sudo apt install -y nvidia-docker2
sudo systemctl restart docker
sudo usermod -aG docker $USER

# Prompt for logout and login to apply group changes
if [[ -z "${KAMIWAZA_INSTALL_UNATTENDED}" ]]; then
    read -p "Please log out and log back in for the group changes to take effect. Run script 3.sh after that."
else
    echo "unattended mode, running 3.sh with su for the docker group..."
    exec su - $USER -c "./3.sh"
fi

