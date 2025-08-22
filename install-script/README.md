# scripted install

These scripts are relatively lightly tested, but we have run them multiple times on Azure Canonical Ubuntu 22.04LTS-Server instances.

The flow is essentially:

1. `bash 1.sh`
2. reboot
3. `bash 2.sh`
4. log out, back in
5. `bash 3.sh`

That concludes with it launching the kamiwaza `install.sh`

These scripts include pulling the kamiwaza tar.gz from github.

These are Ubuntu Linux only, there is not an osx equivalent.

## Script Descriptions

### 1.sh - System Preparation and NVIDIA Driver Installation
This script performs the initial system setup and prepares the environment for Kamiwaza installation:
- Updates and upgrades Ubuntu system packages
- Installs Python 3.10, development libraries, and essential tools (golang-cfssl, etcd-client, net-tools, jq)
- Installs Docker and Docker Compose
- Downloads and installs CockroachDB
- Installs NVIDIA graphics drivers (version 550 or higher, with automatic detection of recommended drivers)
- Requires a system reboot after completion to activate the NVIDIA drivers

### 2.sh - NVIDIA Container Runtime Setup
This script configures Docker to work with NVIDIA GPUs:
- Installs the NVIDIA container toolkit and nvidia-docker2
- Configures Docker to support GPU containers
- Adds the current user to the docker group for non-root Docker access
- Restarts Docker service to apply the new configuration
- Requires user to log out and back in (or handles this automatically in unattended mode)

### 3.sh - Kamiwaza Download and Installation
This script completes the Kamiwaza installation process:
- Tests NVIDIA driver and Docker GPU integration using a CUDA container
- Downloads the Kamiwaza Community Edition tar.gz from GitHub
- Extracts the Kamiwaza package and runs the main install.sh script
- Provides final installation completion message

### mountlocal.sh - Azure VM Disk Management (Optional)
This is an advanced Azure-specific script for automatic disk mounting:
- Automatically detects and mounts available Azure VM disks (NVMe, resource disks, etc.)
- Creates appropriate filesystems and mount points for scratch storage
- Manages persistent storage configuration
- Updates /etc/fstab for persistent mounts across reboots
- Includes safety checks and cleanup routines for stale mounts
- Only runs on Azure VMs and is skipped for Community Edition installations
