#!/bin/bash

# Kamiwaza automount script for Azure VMs
# Version: 1.4

# PRESERVED: Original header and variable definitions
set -eo pipefail

if [ -f "$(dirname "${BASH_SOURCE[0]}")/.kamiwaza_install_community" ]; then
    echo "=== Kamiwaza Community Edition detected, skipping mountlocal.sh"
    exit 0
fi

# Define variables
PRIMARY_MOUNT_POINT="/mnt"
SECONDARY_MOUNT_POINT="/scratch"
KAMIWAZA_MOUNT_POINT="/opt/kamiwaza"
USER=$(whoami)
TMP_DIR="/home/$USER/tmp"
DISK_SIZE_THRESHOLD=250000  # Size threshold in MB for identifying the 256GB disk
DRY_RUN=false
LOCK_FILE="/tmp/kamiwaza_mount.lock"
# Add after existing variable definitions
declare -a BLACKLISTED_DISKS=()
declare -a AVAILABLE_DISKS=()
declare -a SCRATCH_MOUNTS=()
LARGEST_SCRATCH_DISK=""
LARGEST_SCRATCH_SIZE=0
SCRATCH_COUNT=1

if [ "$UID" -eq 0 ]; then
    error_log "This script should be run as the kamiwaza install user, not root"
    exit 1
fi

declare -a ACTIONS_TAKEN=()
# Add this at the start of the script with other global vars
declare -a MOUNTED_DEVICES=()
declare -a MOUNTED_POINTS=()

# Modify the logging functions
log() {
    local message=$1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
    # Only track actual actions, not informational messages
    if [[ "$message" =~ ^"Successfully mounted"|"Created filesystem"|"Partitioned"|"Updated fstab"|"Cleaned up" ]]; then
        ACTIONS_TAKEN+=("$message")
    fi
}

error_log() {
    local message=$1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >&2
    logger -t mountlocal "ERROR: $message"
    ACTIONS_TAKEN+=("ERROR: $message")
}

# Then modify cleanup() to report
cleanup() {
    if [ ${#ACTIONS_TAKEN[@]} -gt 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Actions performed:"
        printf '%s\n' "${ACTIONS_TAKEN[@]}" | sed 's/^/  /'
    fi
    release_lock
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup completed."
}

acquire_lock() {
    touch "$LOCK_FILE"
    exec 200>"$LOCK_FILE"
    flock -n 200 || { error_log "Another instance of the script is running. Exiting."; exit 1; }
}

release_lock() {
    if [ -e "$LOCK_FILE" ]; then
        flock -u 200 2>/dev/null || true
        exec 200>&- 2>/dev/null || true
        rm -f "$LOCK_FILE"
    fi
}

check_azure() {
    if curl -H "Metadata: true" -s -f "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 2>/dev/null | grep -q "AzurePublicCloud"; then
        return 0
    else
        return 1
    fi
}

get_partition_name() {
    local device=$1
    local result=""
    
    log "DEBUG: get_partition_name input: $device" >&2

    # First resolve any symlinks to get real device
    local real_device=""
    if [[ "$device" =~ ^/dev/disk/azure ]]; then
        real_device=$(readlink -f "$device")
        log "DEBUG: resolved stable path $device to $real_device" >&2
    else
        real_device="$device"
    fi
    
    # If it's already a partition, return as-is
    if [[ "$real_device" =~ nvme[0-9]+n[0-9]+p[0-9]+$ ]] || [[ "$real_device" =~ [0-9]$ && ! "$real_device" =~ nvme ]]; then
        result="$real_device"
    elif [[ "$real_device" =~ ^/dev/nvme[0-9]+n[0-9]+$ ]]; then
        result="${real_device}p1"
    elif [[ "$real_device" == /dev/sd* ]]; then
        result="${real_device}1"
    else
        result="$real_device"
    fi
    
    log "DEBUG: get_partition_name output: $result" >&2
    echo "$result"
}

cleanup_stale_mounts() {
    if [ "$DRY_RUN" = true ]; then
        log "DRY_RUN: Would clean stale mounts"
        return 0
    fi

    # Clean up stale scratch mounts
    for mount in /scratch*; do
        if [ -d "$mount" ] && mountpoint -q "$mount"; then
            device=$(findmnt -n -o SOURCE "$mount")
            if [ ! -b "$device" ]; then
                log "Cleaning up stale mount $mount"
                safe_unmount "$mount"
                sudo sed -i "\| $mount |d" /etc/fstab
            fi
        fi
    done

    # Remove Azure resource disk entry if it exists
    sudo sed -i '/\/dev\/disk\/cloud\/azure_resource-part1/d' /etc/fstab
}

cleanup_fstab() {
    if [ "$DRY_RUN" = true ]; then
        log "DRY_RUN: Would clean fstab"
        return 0
    fi

    # Make backup with timestamp
    local backup_file="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/fstab "$backup_file"

    # Remove entries for non-existent devices
    while read -r line; do
        if [[ "$line" =~ ^/dev/ ]]; then
            device=$(echo "$line" | awk '{print $1}')
            if [ ! -b "$device" ]; then
                log "Removing stale fstab entry for $device"
                sudo sed -i "\|^$device|d" /etc/fstab
            fi
        fi
    done < /etc/fstab

    # Remove duplicate entries
    sudo awk '!seen[$0]++' /etc/fstab | sudo tee /etc/fstab.tmp > /dev/null
    sudo mv /etc/fstab.tmp /etc/fstab

    manage_fstab_backups
}

handle_scratch_mounts() {
    local primary_mounted=false
    local primary_attempted=false
    local -a used_disks=()
    local -a used_uuids=()
    local -a failed_disks=()

    # Verify state before proceeding
    if ! verify_global_state; then
        error_log "Invalid state before handling scratch mounts"
        return 1
    fi

    # First, record persistence disk UUID if it exists
    if [ -n "$PERSISTENCE_DISK" ]; then
        local persistence_real=$(readlink -f "$PERSISTENCE_DISK")
        used_disks+=("$persistence_real")
        local persistence_uuid=$(sudo blkid -s UUID -o value "${persistence_real}1" 2>/dev/null || true)
        if [ -n "$persistence_uuid" ]; then
            used_uuids+=("$persistence_uuid")
        fi
    fi

    # Try NVMe disk first if available
    if [ -n "$NVME_DISK" ]; then
        log "Attempting to mount NVMe disk as primary scratch"
        primary_attempted=true
        local nvme_real=$(readlink -f "$NVME_DISK")
        local nvme_partition=$(get_partition_name "$NVME_DISK")
        if prepare_and_mount_disk "$NVME_DISK" "$PRIMARY_MOUNT_POINT"; then
            track_mount "$nvme_partition" "$PRIMARY_MOUNT_POINT"
            setup_tmp_dir "$PRIMARY_MOUNT_POINT"
            primary_mounted=true
            SCRATCH_MOUNTS+=("$PRIMARY_MOUNT_POINT")
            used_disks+=("$nvme_real")
            log "Successfully mounted NVMe disk at $PRIMARY_MOUNT_POINT"
        else
            error_log "Failed to prepare/mount NVMe disk"
            failed_disks+=("$nvme_real")
        fi
    fi

    # Then handle resource disk if available
    if [ -n "$RESOURCE_DISK" ]; then
        local resource_real=$(readlink -f "$RESOURCE_DISK")
        # Only process if we haven't used or failed with this disk
        if [[ ! " ${used_disks[@]} " =~ " ${resource_real} " ]] && 
           [[ ! " ${failed_disks[@]} " =~ " ${resource_real} " ]]; then
            
            if [ "$primary_attempted" = false ]; then
                log "Attempting to mount resource disk as primary scratch"
                if ! grep -q "^$(get_partition_name "$RESOURCE_DISK") $KAMIWAZA_MOUNT_POINT " /proc/mounts; then
                    if prepare_and_mount_disk "$RESOURCE_DISK" "$PRIMARY_MOUNT_POINT"; then
                        setup_tmp_dir "$PRIMARY_MOUNT_POINT"
                        local partition_name
                        partition_name="$(get_partition_name "$RESOURCE_DISK")" || return 1
                        track_mount "$partition_name" "$PRIMARY_MOUNT_POINT"
                        primary_mounted=true
                        SCRATCH_MOUNTS+=("$PRIMARY_MOUNT_POINT")
                        used_disks+=("$resource_real")
                        log "Successfully mounted resource disk at $PRIMARY_MOUNT_POINT"
                    else
                        error_log "Failed to prepare/mount resource disk"
                        failed_disks+=("$resource_real")
                    fi
                else
                    log "Resource disk is being used for persistence, skipping"
                    used_disks+=("$resource_real")
                fi
            else
                # Use as secondary if primary was attempted
                log "Attempting to mount resource disk as secondary scratch"
                if prepare_and_mount_disk "$RESOURCE_DISK" "${SECONDARY_MOUNT_POINT}1"; then
                    local partition_name
                    partition_name="$(get_partition_name "$RESOURCE_DISK")" || return 1
                    track_mount "$partition_name" "${SECONDARY_MOUNT_POINT}1"
                    SCRATCH_MOUNTS+=("${SECONDARY_MOUNT_POINT}1")
                    used_disks+=("$resource_real")
                    log "Successfully mounted resource disk at ${SECONDARY_MOUNT_POINT}1"
                else
                    error_log "Failed to prepare/mount resource disk"
                    failed_disks+=("$resource_real")
                fi
            fi
        else
            log "DEBUG: Skipping resource disk - already processed"
        fi
    fi

    # Handle remaining disks, excluding any we've already used or that failed
    for disk in "${AVAILABLE_DISKS[@]}"; do
        # Skip if we've already used or failed with this disk
        local real_disk=$(readlink -f "$disk")
        if [[ " ${used_disks[@]} " =~ " ${real_disk} " ]] || 
           [[ " ${failed_disks[@]} " =~ " ${real_disk} " ]]; then
            log "DEBUG: Skipping already processed disk: $disk"
            continue
        fi

        local disk_uuid=$(sudo blkid -s UUID -o value "${real_disk}1" 2>/dev/null || true)
        # Skip if disk matches persistence UUID
        if [ -n "$disk_uuid" ] && [[ " ${used_uuids[@]} " =~ " ${disk_uuid} " ]]; then
            log "DEBUG: Skipping disk with used UUID: $disk (UUID: $disk_uuid)"
            continue
        fi

        if [ "$disk" = "$LARGEST_SCRATCH_DISK" ] && [ "$primary_mounted" = false ] && [ "$primary_attempted" = false ]; then
            log "Attempting to mount largest available disk as primary scratch"
            if prepare_and_mount_disk "$disk" "$PRIMARY_MOUNT_POINT"; then
                setup_tmp_dir "$PRIMARY_MOUNT_POINT"
                local partition_name
                partition_name="$(get_partition_name "$disk")" || return 1
                track_mount "$partition_name" "$PRIMARY_MOUNT_POINT"
                primary_mounted=true
                SCRATCH_MOUNTS+=("$PRIMARY_MOUNT_POINT")
                used_disks+=("$real_disk")
                log "Successfully mounted largest available disk at $PRIMARY_MOUNT_POINT"
            else
                error_log "Failed to prepare/mount largest available disk"
                failed_disks+=("$real_disk")
            fi
        else
            # Only mount as secondary if we haven't used this disk yet
            log "Attempting to mount additional scratch disk at ${SECONDARY_MOUNT_POINT}${SCRATCH_COUNT}"
            if prepare_and_mount_disk "$disk" "${SECONDARY_MOUNT_POINT}${SCRATCH_COUNT}"; then
                local partition_name
                partition_name="$(get_partition_name "$disk")" || return 1
                track_mount "$partition_name" "${SECONDARY_MOUNT_POINT}${SCRATCH_COUNT}"
                SCRATCH_MOUNTS+=("${SECONDARY_MOUNT_POINT}${SCRATCH_COUNT}")
                used_disks+=("$real_disk")
                log "Successfully mounted additional scratch disk at ${SECONDARY_MOUNT_POINT}${SCRATCH_COUNT}"
                ((SCRATCH_COUNT++))
            else
                error_log "Failed to prepare/mount additional scratch disk"
                failed_disks+=("$real_disk")
            fi
        fi
    done

    # Verify final state of scratch mounts
    if ! verify_global_state; then
        error_log "Invalid state after handling scratch mounts"
        return 1
    fi

    # If we got here but have no primary mount, that's a problem worth noting
    if [ "$primary_mounted" = false ]; then
        error_log "Warning: No primary scratch mount could be established"
        return 1
    fi

    return 0
}

is_partitioned() {
    local disk=$1
    local real_disk=$(readlink -f "$disk")
    
    if [[ $real_disk == /dev/nvme* ]]; then
        [[ -b "${real_disk}p1" ]]
    else
        [[ -b "${real_disk}1" ]]
    fi
}

# Function to safely partition a disk
safe_partition() {
    local disk=$1
    if ! is_partitioned "$disk"; then
        log "Partitioning $disk..."
        if [ "$DRY_RUN" = false ]; then
            # Check if this disk has any existing partition with data
            local partition=$(get_partition_name "$disk")
            if [ -b "$partition" ] && has_filesystem "$partition"; then
                log "Found existing partition and filesystem on $partition - skipping partition creation"
                return 0
            fi
            
            # Create new GPT partition table and primary partition with -s flag to prevent prompts
            if ! sudo parted -s "$disk" mklabel gpt; then
                error_log "Failed to create GPT label on $disk"
                return 1
            fi
            
            if ! sudo parted -s "$disk" mkpart primary ext4 0% 100%; then
                error_log "Failed to create partition on $disk"
                return 1
            fi

            # Force kernel to reread partition table
            sudo partprobe "$disk"
            sleep 2  # Give system time to recognize new partition
            
            if ! is_partitioned "$disk"; then
                error_log "Failed to partition $disk"
                return 1
            fi
        fi
    else
        log "$disk is already partitioned. Skipping partitioning."
    fi
    return 0
}

has_filesystem() {
    local partition=$1
    
    # First check if it's already mounted - if so, it definitely has a working filesystem
    if findmnt -S "$partition" -n &>/dev/null; then
        local current_mount
        current_mount=$(findmnt -S "$partition" -n -o TARGET)
        log "DEBUG: $partition is mounted at $current_mount"
        return 0
    fi
    
    # Get filesystem type, explicitly handling empty output
    local fs_type
    fs_type=$(sudo blkid -s TYPE -o value "$partition" | tr -d '[:space:]')
    
    if [ -n "$fs_type" ]; then
        log "DEBUG: Found filesystem type '$fs_type' on $partition"
        return 0
    else
        # Extra debug info if no filesystem type found
        local all_info
        all_info=$(sudo blkid "$partition" 2>/dev/null || echo "No blkid information found")
        log "DEBUG: No filesystem type found on $partition (blkid output: $all_info)"
        return 1
    fi
}

safe_mount() {
    local device=$1
    local mount_point=$2
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY_RUN: Would mount $device at $mount_point"
        return 0
    fi
    
    sudo mount "$device" "$mount_point" || return 1
    
    # Verify mount succeeded
    if ! mountpoint -q "$mount_point"; then
        error_log "Mount verification failed for $mount_point"
        return 1
    fi
    
    return 0
}

wait_for_partition() {
    local partition=$1
    local max_wait=30
    local count=0
    
    while [ ! -b "$partition" ] && [ $count -lt $max_wait ]; do
        sleep 1
        ((count++))
    done
    
    [ -b "$partition" ]
}

safe_mkfs() {
    local partition=$1
    log "DEBUG: safe_mkfs called with: $partition"
    
    if ! has_filesystem "$partition"; then
        log "Creating ext4 filesystem on $partition..."
        if [ "$DRY_RUN" = false ]; then
            log "Starting formatting - this may take a while for large devices..."
            # Debug current mounts
            log "DEBUG: Current mounts:"
            findmnt | grep -E "^$partition|^${partition%[0-9]}" || true
            
            # Add -F to force formatting without prompting
            if ! sudo mkfs.ext4 -F "$partition"; then
                error_log "Failed to create filesystem on $partition"
                return 1
            fi
            
            log "Format completed, waiting for partition..."
            wait_for_partition "$partition" || {
                error_log "Failed to verify partition after formatting"
                return 1
            }
            if ! has_filesystem "$partition"; then
                error_log "Failed to create filesystem on $partition"
                return 1
            fi
            log "Filesystem creation complete"
        fi
    else
        log "DEBUG: Filesystem check result for $partition:"
        sudo blkid "$partition" || true
        log "$partition already has a filesystem. Skipping formatting."
    fi
}

# Function to safely unmount a disk
safe_unmount() {
    local mount_point=$1
    if mountpoint -q "$mount_point"; then
        log "Unmounting $mount_point"
        if [ "$DRY_RUN" = false ]; then
            sudo umount "$mount_point" || { error_log "Failed to unmount $mount_point"; return 1; }
        fi
    else
        log "$mount_point is not mounted"
    fi
    return 0
}

update_fstab() {
    local device=$1
    local mount_point=$2
    local options="defaults,nofail,x-systemd.device-timeout=5"

    # Protected mount points - keep this list in sync with our other safety checks
    local -a protected_mounts=("/" "/boot" "/boot/efi" "/etc" "/var")

    # Safeguard: Never modify entries for protected mount points
    for protected in "${protected_mounts[@]}"; do
        if [[ "$mount_point" == "$protected" || "$mount_point" == "$protected/"* ]]; then
            log "WARNING: Attempted to modify fstab entry for protected mount point: $mount_point. Skipping."
            return 1
        fi
    done

    if [ "$DRY_RUN" = false ]; then
        # Make backup with timestamp
        local backup_file="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
        sudo cp /etc/fstab "$backup_file"

        # Determine if this is an ephemeral disk
        local is_ephemeral=false
        local stable_path=""
        
        # Check if it's the resource disk
        if [[ "$device" == *"/dev/sdb1" ]] || [[ "$(readlink -f "$device")" == "/dev/sdb1" ]]; then
            is_ephemeral=true
            stable_path="/dev/disk/azure/resource-part1"
        # Check if it's an NVMe disk
        elif [[ "$device" == *"/dev/nvme"* ]]; then
            is_ephemeral=true
            stable_path="$device"  # Use direct nvme path
        fi

        # For ephemeral disks, use device path. For persistent disks, use UUID
        local fstab_device=""
        if [ "$is_ephemeral" = true ]; then
            fstab_device="$stable_path"
            log "Using stable path $stable_path for ephemeral device $device"
        else
            # Get UUID for persistent devices
            local uuid=$(sudo blkid -s UUID -o value "$device")
            if [ -z "$uuid" ]; then
                error_log "Failed to get UUID for device $device"
                return 1
            fi
            fstab_device="UUID=$uuid"
            log "DEBUG: Using UUID=$uuid for persistent device $device"
        fi

        # Carefully update fstab:
        # 1. Only remove entries for THIS mount point if it's not protected
        # 2. Only remove entries for THIS device/UUID if they're not for protected mounts
        while IFS= read -r line; do
            if [[ "$line" =~ ^[^#] ]]; then  # Skip comments
                read -r dev mnt fs opts dump pass <<< "$line"
                
                # Skip this line if it's for a protected mount
                local is_protected=false
                for protected in "${protected_mounts[@]}"; do
                    if [[ "$mnt" == "$protected" || "$mnt" == "$protected/"* ]]; then
                        is_protected=true
                        break
                    fi
                done
                [ "$is_protected" = true ] && continue

                # For resource disk, check for stale UUIDs
                if [[ "$device" == *"/dev/disk/azure/resource"* ]] || [[ "$(readlink -f "$device")" == "/dev/sdc"* ]]; then
                    if [[ "$dev" =~ ^UUID=([a-f0-9-]+) ]] && [[ "$mnt" =~ ^/(mnt|scratch[0-9]*) ]]; then
                        local old_uuid="${BASH_REMATCH[1]}"
                        # Verify this UUID doesn't exist on any current disk
                        local current_disks_with_uuid
                        current_disks_with_uuid=$(sudo blkid | grep -w "UUID=\"$old_uuid\"" || true)
                        if [ -z "$current_disks_with_uuid" ]; then
                            log "Removing stale UUID=$old_uuid entry for mount $mnt"
                            sudo sed -i "\|^UUID=$old_uuid[[:space:]]|d" /etc/fstab
                        fi
                    fi
                fi

                # Now safe to remove entries for our device/mount
                if [[ "$mnt" == "$mount_point" ]]; then
                    sudo sed -i "\|^.*[[:space:]]$mount_point[[:space:]].*$|d" /etc/fstab
                fi
            fi
        done < /etc/fstab

        # Add new entry
        echo "$fstab_device $mount_point ext4 $options 0 2" | sudo tee -a /etc/fstab

        # Cleanup duplicates while preserving protected entries
        sudo awk '!seen[$0]++ || $2 ~ "^/($|boot|etc|var).*"' /etc/fstab | sudo tee /etc/fstab.tmp > /dev/null
        sudo mv /etc/fstab.tmp /etc/fstab
        
        # Manage backups
        manage_fstab_backups

        log "Updated fstab: $fstab_device mounted at $mount_point"
    fi
}

cleanup_azure_mounts() {
    local -a protected_mounts=("/" "/boot" "/boot/efi" "/etc" "/var" "$KAMIWAZA_MOUNT_POINT")
    log "DEBUG: Checking for Azure resource disk mounts to clean up"
    
    # First check fstab for Azure resource disk entries
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check for KAMIWAZAKEEP directive
        local prev_line
        prev_line=$(grep -B1 "^${line}$" /etc/fstab | head -n1)
        if [[ "$prev_line" == *"KAMIWAZAKEEP"* ]]; then
            log "DEBUG: Found KAMIWAZAKEEP directive for mount: $line"
            continue
        fi

        # Look for Azure resource disk mounts that aren't UUID-based
        if [[ "$line" =~ /dev/(disk/azure/resource|disk/cloud/azure_resource|sdb) ]]; then
            read -r dev mnt fs opts dump pass <<< "$line"
            
            # Skip if it's a protected mount point
            local is_protected=false
            for protected in "${protected_mounts[@]}"; do
                if [[ "$mnt" == "$protected" || "$mnt" == "$protected/"* ]]; then
                    is_protected=true
                    break
                fi
            done
            [ "$is_protected" = true ] && continue

            # Get the real device
            local real_device
            real_device=$(readlink -f "$dev" || echo "$dev")
            
            # If it's mounted, unmount it
            if findmnt -n -S "$real_device" &>/dev/null; then
                log "Found Azure resource disk mounted at $mnt from $dev"
                while findmnt -n -S "$real_device" &>/dev/null; do
                    local current_mount
                    current_mount=$(findmnt -n -S "$real_device" -o TARGET | tail -1)
                    log "Unmounting resource disk from $current_mount"
                    sudo umount "$real_device" || {
                        error_log "Failed to unmount resource disk from $current_mount"
                        break
                    }
                done
            fi

            # Remove from fstab unless it has KAMIWAZAKEEP
            log "Removing non-UUID Azure resource disk entry from fstab: $dev"
            sudo sed -i "\|^${dev}[[:space:]]|d" /etc/fstab
        fi
    done < /etc/fstab
}

verify_mount_point() {
    local mount_point=$1
    # Check if mount point is under a protected directory
    for protected in / /boot /boot/efi /etc /var; do
        if [[ "$mount_point" == "$protected" ]]; then
            return 1
        fi
    done
    return 0
}

verify_mount_consistency() {
    local mount_point=$1
    local expected_device=$2
    
    log "DEBUG: verify_mount_consistency checking $mount_point, expecting $expected_device"
    
    if ! mountpoint -q "$mount_point"; then
        log "DEBUG: $mount_point is not a mountpoint"
        return 1
    fi
    
    local current_device=$(findmnt -n -o SOURCE "$mount_point")
    log "DEBUG: Current device at $mount_point is: $current_device"
    
    if [ "$current_device" != "$expected_device" ]; then
        log "DEBUG: Mount mismatch: expected=$expected_device, got=$current_device"
        return 1
    fi
    
    return 0
}

# Function to set up the tmp directory
setup_tmp_dir() {
    local mount_point=$1

    if [ ! -d "$mount_point/tmp" ]; then
        log "Creating target directory $mount_point/tmp..."
        if [ "$DRY_RUN" = false ]; then
            sudo mkdir -p "$mount_point/tmp"
            sudo chown -R "$USER:$USER" "$mount_point/tmp"
            sudo chmod 755 "$mount_point/tmp"
        fi
    fi

    if [ -L "$TMP_DIR" ] && [ "$(readlink -f "$TMP_DIR")" == "$mount_point/tmp" ]; then
        log "Tmp directory is already set up correctly at $TMP_DIR"
    else
        if [ -d "$TMP_DIR" ] || [ -L "$TMP_DIR" ]; then
            if [ "$DRY_RUN" = false ]; then
                rm -rf "$TMP_DIR"
            fi
        fi

        if [ "$DRY_RUN" = false ]; then
            ln -s "$mount_point/tmp" "$TMP_DIR"
        fi
        log "Tmp directory symlink created at $TMP_DIR"
    fi

    if [ "$DRY_RUN" = false ]; then
        sudo chown -R "$USER:$USER" "$mount_point/tmp"
        mkdir -p "$mount_point/tmp/models"
        mkdir -p "$mount_point/tmp/.kamiwaza_cache"
    fi

    log "Tmp directory setup completed at $TMP_DIR"
}

identify_azure_disks() {
    # Initialize all disk variables with stable paths where possible
    ROOT_DISK=""
    ROOT_UUID=""
    ROOT_REAL=""
    RESOURCE_DISK=""
    PERSISTENCE_DISK=""
    NVME_DISK=""
    
    # First carefully identify and verify root disk
    if [ -L "/dev/disk/azure/root" ]; then
        ROOT_DISK="/dev/disk/azure/root"
        ROOT_REAL=$(readlink -f "$ROOT_DISK" || true)
        if [ ! -b "$ROOT_REAL" ]; then
            error_log "Root disk symlink broken or missing: $ROOT_DISK -> $ROOT_REAL"
            exit 1
        fi
        ROOT_UUID=$(sudo blkid -s UUID -o value "${ROOT_REAL}1" 2>/dev/null || true)
        ROOT_MOUNT_UUID=$(findmnt -n -o UUID / 2>/dev/null || true)
        
        if [ -n "$ROOT_UUID" ] && [ -n "$ROOT_MOUNT_UUID" ] && [ "$ROOT_UUID" = "$ROOT_MOUNT_UUID" ]; then
            log "Identified root disk: $ROOT_REAL (stable path: $ROOT_DISK, UUID: $ROOT_UUID)"
            BLACKLISTED_DISKS+=("$ROOT_DISK")
        else
            error_log "Root disk UUID mismatch or not found - this is unexpected!"
            error_log "Root mount UUID: $ROOT_MOUNT_UUID"
            error_log "Device UUID: $ROOT_UUID"
            exit 1
        fi
    else
        error_log "No root disk found in /dev/disk/azure/root"
        exit 1
    fi

    # Identify resource disk using stable path
    if [ -L "/dev/disk/azure/resource" ]; then
        RESOURCE_DISK="/dev/disk/azure/resource"
        RESOURCE_REAL=$(readlink -f "$RESOURCE_DISK" || true)
        if [ ! -b "$RESOURCE_REAL" ]; then
            error_log "Resource disk symlink broken or missing: $RESOURCE_DISK -> $RESOURCE_REAL"
            exit 1
        fi
        log "Identified resource disk: $RESOURCE_REAL (stable path: $RESOURCE_DISK)"
    fi

    # For persistence disk, check in this order:
    # 1. Currently mounted (with UUID verification)
    # 2. In fstab (with UUID verification)
    # 3. Azure SCSI devices
    PERSISTENCE_DISK=""
    
    if mountpoint -q "$KAMIWAZA_MOUNT_POINT" 2>/dev/null; then
        mounted_device=$(findmnt -n -o SOURCE "$KAMIWAZA_MOUNT_POINT" 2>/dev/null || true)
        mounted_uuid=$(findmnt -n -o UUID "$KAMIWAZA_MOUNT_POINT" 2>/dev/null || true)
        
        # Verify this isn't accidentally the root filesystem
        if [ -n "$ROOT_UUID" ] && [ -n "$mounted_uuid" ] && [ "$mounted_uuid" = "$ROOT_UUID" ]; then
            error_log "Root filesystem detected at $KAMIWAZA_MOUNT_POINT - this is incorrect"
            log "Unmounting root filesystem from incorrect mount point"
            safe_unmount "$KAMIWAZA_MOUNT_POINT"
        else
            # Try to find stable path for mounted device
            while read -r lun; do
                if [ -L "$lun" ] && [ "$(readlink -f "$lun" || true)" = "$(readlink -f "$mounted_device" | sed 's/[0-9]*$//' || true)" ]; then
                    PERSISTENCE_DISK="$lun"
                    log "Found persistence disk from current mount using stable path: $PERSISTENCE_DISK"
                    break
                fi
            done < <(find /dev/disk/azure/scsi1/ -name "lun*" -type l 2>/dev/null || true)

            # If no stable path found but device exists and isn't root
            if [ -z "$PERSISTENCE_DISK" ] && [ -b "$mounted_device" ]; then
                PERSISTENCE_DISK=$(echo "$mounted_device" | sed 's/[0-9]*$//')
                log "Found persistence disk from current mount (no stable path): $PERSISTENCE_DISK"
            fi
            [ -n "$PERSISTENCE_DISK" ] && BLACKLISTED_DISKS+=("$PERSISTENCE_DISK")
        fi
    fi

    # If not found in current mounts, check fstab
    if [ -z "$PERSISTENCE_DISK" ]; then
        fstab_device=$(grep " $KAMIWAZA_MOUNT_POINT " /etc/fstab 2>/dev/null | awk '{print $1}' || true)
        if [[ "$fstab_device" =~ ^UUID= ]]; then
            fstab_uuid=${fstab_device#UUID=}
            if [ "$fstab_uuid" = "$ROOT_UUID" ]; then
                log "Removing incorrect root disk fstab entry for $KAMIWAZA_MOUNT_POINT"
                sudo sed -i "\| $KAMIWAZA_MOUNT_POINT |d" /etc/fstab
            else
                # Try to find device by UUID
                while read -r dev; do
                    if [ -b "$dev" ]; then
                        dev_uuid=$(sudo blkid -s UUID -o value "$dev" 2>/dev/null || true)
                        if [ -n "$dev_uuid" ] && [ "$dev_uuid" = "$fstab_uuid" ]; then
                            PERSISTENCE_DISK=$(echo "$dev" | sed 's/[0-9]*$//')
                            log "Found persistence disk from fstab UUID: $PERSISTENCE_DISK"
                            break
                        fi
                    fi
                done < <(find /dev -name 'sd[a-z]1' -o -name 'nvme[0-9]n[0-9]p1' 2>/dev/null || true)
            fi
        elif [ -n "$fstab_device" ] && [ -b "$fstab_device" ]; then
            device_uuid=$(sudo blkid -s UUID -o value "$fstab_device" 2>/dev/null || true)
            if [ -n "$device_uuid" ] && [ "$device_uuid" = "$ROOT_UUID" ]; then
                log "Removing incorrect root disk fstab entry for $KAMIWAZA_MOUNT_POINT"
                sudo sed -i "\| $KAMIWAZA_MOUNT_POINT |d" /etc/fstab
            elif [ -b "$fstab_device" ]; then
                PERSISTENCE_DISK=$(echo "$fstab_device" | sed 's/[0-9]*$//')
                log "Found persistence disk from fstab (device path): $PERSISTENCE_DISK"
            fi
        fi
        [ -n "$PERSISTENCE_DISK" ] && BLACKLISTED_DISKS+=("$PERSISTENCE_DISK")
    fi

    # After fstab check
    log "DEBUG: Checking SCSI devices"

    # For SCSI device loop
    if [ -z "$PERSISTENCE_DISK" ]; then
        local persistence_candidate=""
        log "DEBUG: Looking for persistence disk in Azure SCSI devices"
        
        while read -r lun; do
            if [ -L "$lun" ]; then
                local real_device
                real_device=$(readlink -f "$lun" || true)
                [ -z "$real_device" ] && continue

                log "DEBUG: Checking LUN: $lun -> $real_device"
                
                # Skip if this is the root or resource disk
                if [ "$real_device" = "$ROOT_REAL" ] || [ "$real_device" = "$RESOURCE_REAL" ]; then
                    log "DEBUG: Skipping $lun as it's root or resource disk"
                    continue
                fi

                # Check if this device has existing data we should preserve
                local partition="${real_device}1"
                log "DEBUG: Checking partition: $partition"
                
                if [ -b "$partition" ] && has_filesystem "$partition"; then
                    local part_uuid
                    part_uuid=$(sudo blkid -s UUID -o value "$partition" 2>/dev/null || true)
                    
                    if [ -n "$part_uuid" ]; then
                        log "DEBUG: Found partition with UUID: $part_uuid"
                        # Verify not root and check if filesystem is writable
                        if [ "$part_uuid" != "$ROOT_UUID" ]; then
                            local tmp_mount
                            tmp_mount=$(mktemp -d)
                            if mount -o ro "$partition" "$tmp_mount" 2>/dev/null; then
                                umount "$tmp_mount" 2>/dev/null
                                PERSISTENCE_DISK="$lun"
                                log "Found formatted persistence disk using stable path: $PERSISTENCE_DISK"
                                BLACKLISTED_DISKS+=("$lun")
                                rmdir "$tmp_mount"
                                break
                            fi
                            rmdir "$tmp_mount"
                        else
                            log "DEBUG: Skipping as UUID matches root"
                        fi
                    fi
                fi

                # Keep first available as candidate
                if [ -z "$persistence_candidate" ]; then
                    persistence_candidate="$lun"
                    log "DEBUG: Saving candidate: $persistence_candidate"
                fi
            fi
        done < <(find /dev/disk/azure/scsi1/ -name "lun*" -type l 2>/dev/null || true)

        # Use candidate if we didn't find a formatted disk
        if [ -z "$PERSISTENCE_DISK" ] && [ -n "$persistence_candidate" ]; then
            PERSISTENCE_DISK="$persistence_candidate"
            log "Using new persistence disk candidate with stable path: $PERSISTENCE_DISK"
        fi
    fi

    # Check for NVMe disk
    if [ -b "/dev/nvme0n1" ]; then
        NVME_DISK="/dev/nvme0n1"
        size=$(get_disk_size "$NVME_DISK" 2>/dev/null || echo 0)
        if [ "$size" -gt 100000 ]; then  # >100GB
            log "Identified suitable NVMe disk: $NVME_DISK ($size MB)"
        else
            NVME_DISK=""
            log "NVMe disk found but too small: /dev/nvme0n1 ($size MB)"
        fi
    fi

    # Final verification and logging
    if [ -z "$PERSISTENCE_DISK" ]; then
        error_log "No suitable persistence disk found - verify Azure SCSI devices are properly attached"
        log "DEBUG: Dumping disk information:"
        log "DEBUG: SCSI1 devices:"
        ls -la /dev/disk/azure/scsi1/ 2>/dev/null || log "DEBUG: No SCSI1 devices found"
        log "DEBUG: Block devices:"
        lsblk 2>/dev/null || true
        log "DEBUG: Available disks:"
        ls -la /dev/sd* /dev/nvme* 2>/dev/null || true
        exit 1
    else
        local persistence_real
        persistence_real=$(readlink -f "$PERSISTENCE_DISK" || true)
        if [ -z "$persistence_real" ] || [ "$persistence_real" = "$ROOT_REAL" ]; then
            error_log "Persistence disk incorrectly identified as root disk or invalid!"
            exit 1
        fi
        log "Final persistence disk selection: $PERSISTENCE_DISK -> $persistence_real"

        # Final size verification
        local persistence_size
        persistence_size=$(get_disk_size "$persistence_real" 2>/dev/null || echo 0)
        if [ "$persistence_size" -lt 10000 ]; then  # 10GB minimum
            error_log "Selected persistence disk too small: $persistence_size MB"
            exit 1
        fi
    fi
}

verify_mounts() {
    local error=false
    
    # Check known mounts
    for mount in "${SCRATCH_MOUNTS[@]}" "$KAMIWAZA_MOUNT_POINT"; do
        if [ -n "$mount" ]; then
            if [ $(grep -c " $mount " /proc/mounts) -gt 1 ]; then
                error_log "Multiple mounts found for $mount"
                error=true
            fi
        fi
    done
    
    # Check for protected mounts being used elsewhere
    for mount in / /boot /boot/efi; do
        device=$(findmnt -n -o SOURCE "$mount")
        if [ $(grep -c "^$device " /proc/mounts) -gt 1 ]; then
            error_log "Protected mount $mount device used elsewhere"
            error=true
        fi
    done
    
    [ "$error" = true ] && return 1
    return 0
}

manage_fstab_backups() {
    # Create a temporary file with a unique name
    local tmp_list=$(mktemp)
    
    # List files in a controlled manner
    find /etc -maxdepth 1 -name 'fstab.bak.*' -type f -printf '%T@ %p\n' | \
        sort -nr | \
        cut -d' ' -f2- > "$tmp_list"
    
    # Keep first 5 files, remove others atomically
    if [ -s "$tmp_list" ]; then
        tail -n +6 "$tmp_list" | xargs -r sudo rm -f
    fi
    
    rm -f "$tmp_list"
}

verify_global_state() {
    local has_errors=false
    log "DEBUG: Verifying global mount state..."

    # Check for stale mount points
    for mp in /mnt /scratch* "$KAMIWAZA_MOUNT_POINT"; do
        if [ -n "$mp" ] && mountpoint -q "$mp"; then
            local device
            device=$(findmnt -n -o SOURCE "$mp")
            log "DEBUG: Found mount point $mp using device $device"

            # Check basic device existence
            if [ ! -b "$device" ]; then
                log "DEBUG: Device $device for mount point $mp is not a block device"
                has_errors=true
                continue
            fi

            # Get full mount info for debugging
            log "DEBUG: Full mount info for $mp:"
            findmnt "$mp" || true
            
            # Check for multiple mounts of same device (warning only)
            local mount_count
            mount_count=$(findmnt -n -S "$device" | wc -l)
            if [ "$mount_count" -gt 1 ]; then
                log "DEBUG: Warning - Device $device is mounted in $mount_count places:"
                findmnt -n -S "$device" || true
            fi
            
            # Extra validation that mount is working
            if ! touch "$mp/.mount_test" 2>/dev/null; then
                log "DEBUG: Warning - Mount point $mp is not writable"
                # Don't fail just for this
            fi
            rm -f "$mp/.mount_test" 2>/dev/null || true
        fi
    done

    # Dump current mount state for debugging
    log "DEBUG: Current mount state:"
    findmnt -t ext4 || true
    
    log "DEBUG: Current fstab entries:"
    grep -v '^#' /etc/fstab || true

    # Be more lenient - only fail if we found actual errors
    if [ "$has_errors" = true ]; then
        error_log "Mount state verification found errors"
        return 1
    fi
    
    log "DEBUG: Mount state verification passed"
    return 0
}

# Add this function
rollback_mount() {
    local mount_point=$1
    safe_unmount "$mount_point"
    sed -i "\| $mount_point |d" /etc/fstab
}

# Function to get disk size in MB
get_disk_size() {
    local disk=$1
    local size=$(sudo blockdev --getsize64 "$disk" 2>/dev/null)
    echo $((size / 1024 / 1024))
}

disable_swap_on_disk() {
    local disk=$1            # e.g. /dev/sdc
    local majmin
    majmin=$(stat -c '%t:%T' "$disk")

    while read -r _ swapdev _; do
        if [ "$(stat -c '%t:%T' "$swapdev")" = "$majmin" ]; then
            echo "[mountlocal] swapoff $swapdev"
            sudo swapoff "$swapdev"
        fi
    done < <(awk 'NR>1 {print $1}' /proc/swaps)
}

# Function to prepare and mount a disk
prepare_and_mount_disk() {
    local disk=$1
    local mount_point=$2
    
    # 1. Safety checks first
    if [[ "$mount_point" == "/" || "$mount_point" == "/boot" || "$mount_point" == "/boot/"* ]]; then
        error_log "Attempted to prepare/mount protected partition: $mount_point. Skipping."
        return 1
    fi

    # 2. Blacklist check and persistence exception
    local real_disk=$(readlink -f "$disk")
    real_disk=$(echo "$real_disk" | sed 's/[0-9]*$//')  # Strip partition number

    # one hyper-active check to avoid touching important disks
    if findmnt -rno TARGET "$real_disk" | egrep -q '^(/|/boot|/boot/efi)$'; then
        error_log "Refusing to operate on a disk that backs the OS or boot partition: $real_disk"
        return 1
    fi

    disable_swap_on_disk "$real_disk"
    
    local is_persistence=false
    if [ "$mount_point" = "$KAMIWAZA_MOUNT_POINT" ] && [ "$real_disk" = "$(readlink -f "$PERSISTENCE_DISK")" ]; then
        is_persistence=true
        log "DEBUG: Allowing blacklisted disk as it is the persistence disk mounting to its proper location"
    else
        for blacklisted in "${BLACKLISTED_DISKS[@]}"; do
            local real_blacklisted=$(readlink -f "$blacklisted")
            if [ "$real_disk" = "$real_blacklisted" ]; then
                error_log "Attempted to prepare/mount blacklisted disk: $disk (resolves to $real_disk) at incorrect location $mount_point"
                return 1
            fi
        done
    fi

    # 3. Get partition name once
    local partition=$(get_partition_name "$disk")
    log "DEBUG: Processing real_disk=$real_disk, partition=$partition"

    # 4. Check current mount status - MODIFIED SECTION
    if findmnt -S "$partition" -n; then
        current_mount_point=$(findmnt -S "$partition" -n -o TARGET)
        if [ "$current_mount_point" = "$mount_point" ]; then
            # NEW: Check if the mount is actually working
            if [ -d "$mount_point" ] && [ -w "$mount_point" ]; then
                log "Partition $partition is already correctly mounted and writable at $mount_point"
                return 0
            else
                log "Partition $partition is mounted but not accessible at $mount_point"
            fi
        else
            # Only try to unmount if it's not the target mount point
            log "$partition is mounted at $current_mount_point. Attempting safe unmount..."
            if ! safe_unmount "$current_mount_point"; then
                if [ "$is_persistence" = true ]; then
                    log "Cannot unmount persistence disk - it's in use. This is okay if mounted correctly."
                    if [ -d "$mount_point" ] && [ -w "$mount_point" ]; then
                        return 0
                    fi
                fi
                error_log "Failed to unmount $partition from $current_mount_point"
                return 1
            fi
        fi
    fi

    # Rest of the function remains the same...
    # 5. Check for existing formatted partition that just needs mounting
    if [ -b "$partition" ] && has_filesystem "$partition" ]; then
        log "Found existing partition with filesystem: $partition"
        if [ "$DRY_RUN" = false ]; then
            sudo mkdir -p "$mount_point"
            update_fstab "$partition" "$mount_point" || {
                error_log "Failed to update fstab for $partition"
                return 1
            }
            if ! findmnt -S "$partition" -n; then
                safe_mount "$partition" "$mount_point" || {
                    error_log "Failed to mount $partition at $mount_point"
                    return 1
                }
            fi
            return 0
        fi
    fi

    # 6. If we get here, we need to partition and format
    log "Preparing disk: $disk (partition: $partition) for mount point: $mount_point"
    safe_partition "$disk" || return 1
    
    if ! wait_for_partition "$partition"; then
        error_log "Timed out waiting for partition $partition"
        return 1
    fi
    
    safe_mkfs "$partition" || return 1

    # 7. Finally mount the prepared disk
    if [ "$DRY_RUN" = false ]; then
        sudo mkdir -p "$mount_point"
        update_fstab "$partition" "$mount_point" || {
            error_log "Failed to update fstab for $partition"
            rollback_mount "$mount_point"
            return 1
        }
        safe_mount "$partition" "$mount_point" || {
            error_log "Failed to mount $partition at $mount_point"
            rollback_mount "$mount_point"
            return 1
        }
    fi

    log "Disk prepared and mounted at $mount_point"
    return 0
}

trap cleanup EXIT

RUN_OUTSIDE_AZURE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --run-outside-azure)
            RUN_OUTSIDE_AZURE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if ! check_azure; then
    if [ "$RUN_OUTSIDE_AZURE" = false ]; then
        log "Not running in Azure environment and --run-outside-azure not specified. Skipping disk operations."
        release_lock
        exit 0
    else
        log "Not running in Azure environment but --run-outside-azure specified. Proceeding with disk operations."
    fi
fi

# Replace existing main execution flow with:

acquire_lock
identify_azure_disks
cleanup_azure_mounts

# Clean up stale mounts first
cleanup_stale_mounts
cleanup_fstab

# After cleanup_stale_mounts and cleanup_fstab, add:
if ! verify_global_state; then
    error_log "Initial state verification failed"
    exit 1
fi

# After cleanup_fstab at the end, add:
manage_fstab_backups

if ! verify_global_state; then
    error_log "Final state verification failed"
    exit 1
fi

# Identify available disks for scratch space
for disk in /dev/sd[a-z] $NVME_DISK; do
    if [ -b "$disk" ] && \
       [ "$disk" != "$ROOT_DISK" ] && \
       [ "$disk" != "$PERSISTENCE_DISK" ] && \
       [ "$disk" != "$RESOURCE_DISK" ]; then
        # Check if this disk is used for / or /boot
        is_system_disk=false
        for mount_point in / /boot /boot/efi; do
            mounted_device=$(findmnt -no SOURCE "$mount_point" 2>/dev/null || echo "")
            if [[ "$mounted_device" == "$disk"* ]]; then
                is_system_disk=true
                break
            fi
        done

        if [ "$is_system_disk" = false ]; then
            size=$(get_disk_size "$disk")
            AVAILABLE_DISKS+=("$disk")
            if [ "$size" -gt "$LARGEST_SCRATCH_SIZE" ]; then
                LARGEST_SCRATCH_SIZE=$size
                LARGEST_SCRATCH_DISK=$disk
            fi
        fi
    fi
done


# Function to add to our tracking arrays
track_mount() {
    local device=$1
    local mount_point=$2
    MOUNTED_DEVICES+=("$device")
    MOUNTED_POINTS+=("$mount_point")
}

# Function to check if device is in our tracking
is_device_mounted() {
    local device=$1
    local real_device
    real_device=$(readlink -f "$device")
    for d in "${MOUNTED_DEVICES[@]}"; do
        if [ "$(readlink -f "$d")" = "$real_device" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check if mount point is in our tracking
is_point_mounted() {
    local mount_point=$1
    for p in "${MOUNTED_POINTS[@]}"; do
        if [ "$p" = "$mount_point" ]; then
            return 0
        fi
    done
    return 1
}

check_mount_conflicts() {
    local device=$1
    local mount_point=$2
    local real_device
    real_device=$(readlink -f "$device")
    
    # Check if device is already mounted somewhere
    if findmnt -n -S "$real_device" &>/dev/null; then
        local current_mounts
        current_mounts=$(findmnt -n -S "$real_device" -o TARGET | tr '\n' ' ')
        log "DEBUG: Device $device is already mounted at: $current_mounts"
        
        # If it's an Azure resource disk and not where we want it, we can unmount it
        if is_azure_resource_disk "$device"; then
            while findmnt -n -S "$real_device" &>/dev/null; do
                local current_mount
                current_mount=$(findmnt -n -S "$real_device" -o TARGET | tail -1)
                log "Unmounting Azure resource disk from $current_mount"
                sudo umount "$real_device" || return 1
            done
            return 0
        fi
        return 1
    fi

    # Check if mount point is already in use
    if findmnt -n "$mount_point" &>/dev/null; then
        local current_device
        current_device=$(findmnt -n -o SOURCE "$mount_point")
        log "DEBUG: Mount point $mount_point is in use by device $current_device"
        
        # If what's mounted there is an Azure resource disk, we can unmount it
        if is_azure_resource_disk "$current_device"; then
            log "Unmounting Azure resource disk from $mount_point"
            sudo umount "$current_device" || return 1
            return 0
        fi
        return 1
    fi

    return 0
}

# Mount persistence disk first
if [ -n "$PERSISTENCE_DISK" ]; then
    if prepare_and_mount_disk "$PERSISTENCE_DISK" "$KAMIWAZA_MOUNT_POINT"; then
        partition_name="$(get_partition_name "$PERSISTENCE_DISK")" || exit 1
        track_mount "$partition_name" "$KAMIWAZA_MOUNT_POINT"
        if [ -d "$KAMIWAZA_MOUNT_POINT" ]; then
            if [ "$DRY_RUN" = false ]; then
                sudo chown "$USER:$USER" "$KAMIWAZA_MOUNT_POINT"
                sudo chown -R "$USER:$USER" "$KAMIWAZA_MOUNT_POINT/kamiwaza" 2>/dev/null || true
                sudo chown -R "$USER:$USER" "$KAMIWAZA_MOUNT_POINT/logs" 2>/dev/null || true
                sudo chown root:root "$KAMIWAZA_MOUNT_POINT/containers" 2>/dev/null || true
            fi
        fi
    else
        error_log "Failed to mount persistence disk ${PERSISTENCE_DISK}"
        exit 1
    fi
fi

# Handle scratch mounts
handle_scratch_mounts

# Verify final mount state
if ! verify_mounts; then
    error_log "Final mount state verification failed"
    exit 1
fi

# Final cleanup of fstab
cleanup_fstab

log "Script completed successfully."
exit 0