#!/bin/bash

set -e  # Exit on any error

# Usage message
usage() {
    echo "Usage: $0 --token <string> --ip <node-external-ip> [--server-ip <ip>] --registration-address <hostname/ip>"
    exit 1
}

# Rollback function
rollback() {
    echo "[ERROR] Rolling back changes..."
    if [[ -f "/usr/local/bin/k3s" ]]; then
        echo "Uninstalling K3s..."
        /usr/local/bin/k3s-uninstall.sh || true
    fi
    exit 1
}

# Ensure rollback runs on failure
trap rollback ERR

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --token)
            K3S_TOKEN="$2"
            shift 2
            ;;
        --registration-address)
            REGISTRATION_ADDRESS="$2"
            shift 2
            ;;
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --ip)
            NODE_EXTERNAL_IP="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$K3S_TOKEN" || -z "$REGISTRATION_ADDRESS" || -z "$NODE_EXTERNAL_IP" ]]; then
    echo "Error: --token, --registration-address, and --ip are required."
    usage
fi

echo "[1/2] Installing K3s with multi-cloud support..."
K3S_INSTALL_ARGS="server --token $K3S_TOKEN"

# If no server-ip is provided, this is the first node (cluster-init)
if [[ -z "$SERVER_IP" ]]; then
    K3S_INSTALL_ARGS="$K3S_INSTALL_ARGS --cluster-init"
else
    K3S_INSTALL_ARGS="$K3S_INSTALL_ARGS --server https://$REGISTRATION_ADDRESS:6443"
fi

K3S_INSTALL_ARGS="$K3S_INSTALL_ARGS \
    --disable traefik \
    --node-external-ip $NODE_EXTERNAL_IP \
    --flannel-backend wireguard-native \
    --flannel-external-ip \
    --tls-san $REGISTRATION_ADDRESS"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$K3S_INSTALL_ARGS" sh -s -

echo "[2/2] Saving kubeconfig..."
sudo cat /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/$REGISTRATION_ADDRESS/g" | tee "kubeconfig.txt" > /dev/null

echo "K3s server setup complete!"
