#!/bin/sh
# Creates zmesh-internal and zmesh-network if they don't exist
# Usage: docker compose run --rm zerotier-controller create-networks

set -e

echo "[create-networks] Creating zmesh networks..."

# Function to safely create or verify network
create_or_verify_network() {
    local network_name=$1
    local subnet=$2
    local bridge_name=$3

    # Check if network exists
    if docker network inspect "$network_name" >/dev/null 2>&1; then
        echo "[create-networks] Network $network_name exists, verifying configuration..."

        # Get current subnet if specified
        if [ -n "$subnet" ]; then
            current_subnet=$(docker network inspect "$network_name" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "")
            if [ "$current_subnet" != "$subnet" ]; then
                echo "[create-networks] ⚠ Subnet mismatch (expected: $subnet, got: $current_subnet)"
                echo "[create-networks] Removing and recreating $network_name..."
                docker network rm "$network_name" 2>/dev/null || true
            else
                echo "[create-networks] ✓ $network_name already exists with correct configuration"
                return 0
            fi
        else
            echo "[create-networks] ✓ $network_name already exists"
            return 0
        fi
    fi

    # Create the network
    echo "[create-networks] Creating $network_name..."
    if [ -n "$subnet" ] && [ -n "$bridge_name" ]; then
        docker network create \
            --driver bridge \
            --subnet="$subnet" \
            --opt com.docker.network.bridge.name="$bridge_name" \
            "$network_name"
    elif [ -n "$subnet" ]; then
        docker network create \
            --driver bridge \
            --subnet="$subnet" \
            "$network_name"
    elif [ -n "$bridge_name" ]; then
        docker network create \
            --driver bridge \
            --opt com.docker.network.bridge.name="$bridge_name" \
            "$network_name"
    else
        docker network create \
            --driver bridge \
            "$network_name"
    fi
    echo "[create-networks] ✓ Created $network_name"
}

# Create or verify zmesh-internal with subnet
create_or_verify_network "zmesh-internal" "172.31.255.0/24" ""

# Create or verify zmesh-network with br-zmesh bridge
create_or_verify_network "zmesh-network" "" "br-zmesh"

echo "[create-networks] Networks ready! Run 'docker compose up -d' to start services."
