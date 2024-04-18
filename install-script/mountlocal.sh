# this is an example script that will autoformat and mount the local disk on an azure instance.
# tested on Standard_NC24ads_A100_v4 but literally once, so YMMV and use at your own risk.
# if run AFTER kamiwaza is installed, it will also modify the default location of the kamiwaza
# model service config so that the directory is used for model downloads
#
# You may not WANT that if you want persistence across reboots; Kamiwaza 0.2.0 will not auto-download missing
# files although you can go to "your models" and just download again (and for files that are checksummable, kamiwaza
# will verify that the last known checksum matches the checksum of the download, so you should still generally not have
# surprise weight changes on a repo/hub model)

#!/bin/bash

# Define the device name, mount point, and user
device="/dev/nvme0n1"
partition="${device}p1"
user="ubuntu"
mount_point="/home/${user}/tmp"

# Check if the partition exists
if sudo fdisk -l $device | grep -q "$partition"; then
    echo "Partition $partition already exists. Skipping partitioning and formatting."
else
    # Partition the disk using fdisk
    sudo fdisk $device << EOF
n
p
1


w
EOF 

    # Format the partition with ext4
    sudo mkfs.ext4 "$partition"
fi

# Create the mount directory if it doesn't exist
sudo mkdir -p $mount_point

# Add the mount entry to /etc/fstab if not already present
if ! grep -q "$partition" /etc/fstab; then
    echo "$partition $mount_point ext4 defaults,nofail,x-systemd.device-timeout=5 0 2" | sudo tee -a /etc/fstab
fi

# Mount the ephemeral disk
sudo mount -a

# Change ownership and permissions of the mount point
sudo chown $user:$user $mount_point
sudo chmod 755 $mount_point

# Check if the mount point exists and is mounted
if mountpoint -q $mount_point; then
    echo "Ephemeral disk successfully mounted at $mount_point"

    # Update the config file
    config_file="kamiwaza/venv/lib/python3.10/site-packages/kamiwaza/services/models/config.py"
    sed -i "s|('file', '/var/tmp/models')|('file', '$mount_point/models')|" $config_file
    sed -i "s|cachedir: str = \"/tmp/.kamiwazi_cache/\"|cachedir: str = \"$mount_point/.kamiwaza_cache/\"|" $config_file

    # Create the necessary directories
    mkdir -p "$mount_point/models"
    mkdir -p "$mount_point/.kamiwaza_cache"

    # Display the mounted disk information
    df -m $mount_point
else
    echo "Failed to mount the ephemeral disk at $mount_point"
fi