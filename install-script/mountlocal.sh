#!/bin/bash

# Kamiwaza automount script for Azure VMs to
# ensure tmp directory is on the big ephemeral disk

set -e  # Exit immediately if a command exits with a non-zero status

# Detect if the OS is macOS (Darwin) and abort if true
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "This script is not supported on macOS (Darwin). Aborting."
    exit 1
fi

# Define variables
primary_mount_point="/mnt"
user=$(whoami)
tmp_dir="/home/$user/tmp"
disk_size_threshold=250000  # Size threshold in MB for identifying the 256GB disk

# Function to set up the tmp directory
setup_tmp_dir() {
    local mount_point=$1

    # Check if the target directory exists in the mount point
    if [ ! -d "$mount_point/tmp" ]; then
        echo "Target directory $mount_point/tmp does not exist. Creating it..."
        sudo mkdir -p "$mount_point/tmp"
        sudo chown -R "$user:$user" "$mount_point/tmp"
        sudo chmod 755 "$mount_point/tmp"
    fi

    # Check if tmp_dir is already set up correctly
    if [ -L "$tmp_dir" ] && [ "$(readlink -f "$tmp_dir")" == "$mount_point/tmp" ]; then
        echo "Tmp directory is already set up correctly at $tmp_dir"
    else
        # Remove existing tmp_dir if it's a directory or symlink
        if [ -d "$tmp_dir" ] || [ -L "$tmp_dir" ]; then
            rm -rf "$tmp_dir"
        fi

        # Create symlink from $mount_point/tmp to /home/$user/tmp
        ln -s "$mount_point/tmp" "$tmp_dir"
        echo "Tmp directory symlink created at $tmp_dir"
    fi

    # Update the config file
    update_config_file

    # Create the necessary directories with proper permissions
    sudo chown -R "$user:$user" "$mount_point/tmp"
    mkdir -p "$mount_point/tmp/models"
    mkdir -p "$mount_point/tmp/.kamiwaza_cache"

    echo "Tmp directory setup completed at $tmp_dir"
    # Display the mounted disk information
    df -h "$mount_point"
}

# Function to update the config file
update_config_file() {
    local config_file=""
    if [ -f "kamiwaza/venv/lib/python3.10/site-packages/kamiwaza/services/models/config.py" ]; then
        config_file="kamiwaza/venv/lib/python3.10/site-packages/kamiwaza/services/models/config.py"
    elif [ -f "venv/lib/python3.10/site-packages/kamiwaza/services/models/config.py" ]; then
        config_file="venv/lib/python3.10/site-packages/kamiwaza/services/models/config.py"
    else
        echo "Config file not found in either kamiwaza/venv or venv"
        return 1
    fi

    # Update the config file without using sudo
    sed -i "s|('file', '/var/tmp/models')|('file', '$tmp_dir/models')|" "$config_file"
    sed -i "s|cachedir: str = \"/tmp/.kamiwazi_cache/\"|cachedir: str = \"$tmp_dir/.kamiwaza_cache/\"|" "$config_file"
}

# Function to check and prepare the disk
prepare_disk() {
    local device=$1
    local partition="${device}1"

    # Check if the device is already mounted
    if mountpoint -q "$primary_mount_point"; then
        echo "Device is already mounted at $primary_mount_point"
        setup_tmp_dir "$primary_mount_point"
        return
    fi

    # Check if the partition exists
    if sudo fdisk -l "$device" | grep -q "$partition"; then
        echo "Partition $partition already exists. Skipping partitioning."
    else
        echo "Partitioning $device..."
        # Partition the disk using fdisk
        sudo fdisk "$device" << EOF
n
p
1


w
EOF
    fi

    # Check if the partition is already formatted
    if ! sudo blkid "$partition" | grep -q "TYPE=\"ext4\""; then
        echo "Formatting $partition with ext4..."
        # Format the partition with ext4
        sudo mkfs.ext4 "$partition"
    else
        echo "Partition $partition is already formatted with ext4."
    fi

    # Create the mount directory if it doesn't exist
    sudo mkdir -p "$primary_mount_point"

    # Add the mount entry to /etc/fstab if not already present
    if ! grep -q "$partition" /etc/fstab; then
        echo "$partition $primary_mount_point ext4 defaults,nofail,x-systemd.device-timeout=5 0 2" | sudo tee -a /etc/fstab
    fi

    # Mount the disk
    sudo mount -a

    # Set up the tmp directory on the disk
    setup_tmp_dir "$primary_mount_point"
}

# Identify the OS disk
os_disk=$(lsblk -o NAME,MOUNTPOINT | grep -E '\/$' | awk '{print $1}')

# Check if there is a large disk (256GB) available and mounted on /mnt
if mountpoint -q "$primary_mount_point" && [ "$(df -BG "$primary_mount_point" | awk 'NR==2 {print $2}' | sed 's/G//')" -gt 100 ]; then
    echo "Large disk detected at $primary_mount_point"
    setup_tmp_dir "$primary_mount_point"
else
    # If no large disk detected at /mnt, find the appropriate disk
    device=""
    for dev in /dev/sd[b-z] /dev/nvme[0-9]n1; do
        if [ "/dev/$os_disk" != "$dev" ] && [ -b "$dev" ]; then
            size=$(sudo blockdev --getsize64 "$dev")
            size_mb=$((size / 1024 / 1024))
            if [ "$size_mb" -ge "$disk_size_threshold" ]; then
                device=$dev
                break
            fi
        fi
    done

    if [ -n "$device" ]; then
        echo "Large disk detected at $device"
        prepare_disk "$device"
    else
        echo "No suitable large disk detected. Exiting."
        exit 1
    fi
fi