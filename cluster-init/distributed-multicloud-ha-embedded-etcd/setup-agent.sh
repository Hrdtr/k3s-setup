#!/bin/bash

set -e

# Usage message
usage() {
    echo "Usage: $0 --token <string> --ip <string> --registration-address <string>"
    exit 1
}

# Options getter
opt() {
    local key="$1"
    shift
    local next_is_value=0

    for arg in "$@"; do
        if [ $next_is_value -eq 1 ]; then
            echo "$arg"
        fi

        case "$arg" in
            "$key")
                next_is_value=1
                ;;
            "$key="*)
                echo "${arg#*=}"
                ;;
        esac
    done
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

K3S_TOKEN="$(opt --token "$@")"
NODE_EXTERNAL_IP="$(opt --ip "$@")"
REGISTRATION_ADDRESS="$(opt --registration-address "$@")"

# Validate required arguments
if [[ -z "$K3S_TOKEN" || -z "$NODE_EXTERNAL_IP" || -z "$REGISTRATION_ADDRESS" ]]; then
    echo "Error: --token, --ip, and --registration-address are required."
    usage
fi

echo "[1/1] Installing K3s agent..."
K3S_AGENT_ARGS="agent \
    --token $K3S_TOKEN \
    --server https://$REGISTRATION_ADDRESS:6443 \
    --node-external-ip $NODE_EXTERNAL_IP"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$K3S_AGENT_ARGS" sh -s -

echo "K3s agent setup complete!"
