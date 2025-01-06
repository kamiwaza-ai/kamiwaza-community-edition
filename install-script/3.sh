# Test NVIDIA driver and Docker integration
docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi

# Download and install Kamiwaza
mkdir kamiwaza
cd kamiwaza
wget https://github.com/kamiwaza-ai/kamiwaza-community-edition/blob/main/kamiwaza-community-0.3.2-UbuntuLinux.tar.gz
tar -xvf kamiwaza-community-0.3.1-UbuntuLinux.tar.gz
bash install.sh

echo "Kamiwaza installation completed. Please follow the post-installation steps to start the services and verify the installation."
