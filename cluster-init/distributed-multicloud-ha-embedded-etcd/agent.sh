#!/bin/bash

set -e  # Exit on any error

# Usage message
usage() {
    echo "Usage: $0 --token <string> --ip <node-external-ip> --registration-address <hostname/ip>"
    exit 1
}

# Rollback function
rollback() {
    echo "[ERROR] Rolling back changes..."
    if [[ -f "/usr/local/bin/k3s" ]]; then
        echo "Uninstalling K3s agent..."
        /usr/local/bin/k3s-agent-uninstall.sh || true
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

echo "[1/1] Installing K3s agent..."
K3S_AGENT_ARGS="agent \
    --token $K3S_TOKEN \
    --server https://$REGISTRATION_ADDRESS:6443 \
    --node-external-ip $NODE_EXTERNAL_IP"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$K3S_AGENT_ARGS" sh -s -

echo "K3s agent setup complete!"
