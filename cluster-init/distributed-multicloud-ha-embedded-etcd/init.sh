#!/bin/bash

set -e  # Exit on any error

# Usage message
usage() {
    echo "Usage: $0 --hostname <hostname> [--swap <size>]"
    exit 1
}

# Rollback function
rollback() {
    echo "[ERROR] Rolling back changes..."
    
    if [[ -n "$HOSTNAME_VALUE" ]]; then
        echo "Restoring original hostname..."
        sudo hostnamectl set-hostname "$ORIGINAL_HOSTNAME"
        sudo sed -i "s/^127.0.1.1.*/127.0.1.1 $ORIGINAL_HOSTNAME/" /etc/hosts
    fi

    if [[ -n "$SWAP_CREATED" ]]; then
        echo "Removing swap file..."
        sudo swapoff /swapfile || true
        sudo rm -f /swapfile
        sudo sed -i '/\/swapfile/d' /etc/fstab
    fi

    exit 1
}

# Ensure rollback runs on failure
trap rollback ERR

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname)
            HOSTNAME_VALUE="$2"
            shift 2
            ;;
        --swap)
            SWAP_SIZE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$HOSTNAME_VALUE" ]]; then
    echo "Error: --hostname is required."
    usage
fi

# Validate swap value
if [[ -n "$SWAP_SIZE" && ! "$SWAP_SIZE" =~ ^[0-9]+(M|G)$ ]]; then
    echo "Error: Invalid swap size format. Use <size>M (MB) or <size>G (GB) (e.g., --swap 1024M or --swap 2G)."
    exit 1
fi

echo "[1/3] Updating system (non-interactive)..."
export DEBIAN_FRONTEND=noninteractive
sudo apt update -yq && sudo apt upgrade -yq

echo "[2/3] Setting hostname..."
ORIGINAL_HOSTNAME=$(hostname)

# Disable automatic hostname updates from cloud-init
sudo sed -i 's/^preserve_hostname: .*/preserve_hostname: true/' /etc/cloud/cloud.cfg

# Set the hostname
sudo hostnamectl set-hostname "$HOSTNAME_VALUE"

# Update /etc/hosts
echo "Updating /etc/hosts..."
sudo sed -i "s/^127.0.1.1 .*/127.0.1.1 $HOSTNAME_VALUE/" /etc/hosts
if ! grep -q "^127.0.1.1" /etc/hosts; then
    echo "127.0.1.1 $HOSTNAME_VALUE" | sudo tee -a /etc/hosts > /dev/null
fi

# Optional swapfile setup
if [[ -n "$SWAP_SIZE" ]]; then
    echo "[3/3] Checking existing swap..."
    if ! sudo swapon --show | grep -q "/swapfile"; then
        echo "Creating swap file of ${SWAP_SIZE}..."
        sudo fallocate -l "$SWAP_SIZE" /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
        SWAP_CREATED=1
        echo "Swap file successfully created and enabled."
    else
        echo "Swap file already exists. Skipping swap setup."
    fi
else
    echo "[3/3] No swap size provided. Skipping swap setup."
fi

echo "System initialization complete!"

# Ask for reboot confirmation
read -p "Reboot now? (y/N): " REBOOT_CONFIRM
if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Rebooting system..."
    sudo reboot
else
    echo "Reboot skipped. Please reboot manually before continuing."
fi
