#!/bin/sh
# Creates zmesh-internal and zmesh-network if they don't exist
# Usage: docker compose run --rm zerotier-controller create-networks

set -e

echo "[create-networks] Creating zmesh networks..."

# Create zmesh-internal
if ! docker network inspect zmesh-internal >/dev/null 2>&1; then
    echo "[create-networks] Creating zmesh-internal with subnet 172.31.255.0/24..."
    docker network create \
        --driver bridge \
        --subnet=172.31.255.0/24 \
        zmesh-internal
    echo "[create-networks] ✓ Created zmesh-internal"
else
    echo "[create-networks] ✓ zmesh-internal already exists"
fi

# Create zmesh-network with br-zmesh bridge
if ! docker network inspect zmesh-network >/dev/null 2>&1; then
    echo "[create-networks] Creating zmesh-network with br-zmesh bridge..."
    docker network create \
        --driver bridge \
        --opt com.docker.network.bridge.name=br-zmesh \
        zmesh-network
    echo "[create-networks] ✓ Created zmesh-network"
else
    echo "[create-networks] ✓ zmesh-network already exists"
fi

echo "[create-networks] Networks ready! Run 'docker compose up -d' to start services."
