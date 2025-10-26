#!/bin/sh
set -e

echo "[zmesh] Starting ZeroTier with zmesh bridge support..."

# Verify zmesh-internal network exists (created by Docker Compose)
if docker network inspect zmesh-internal >/dev/null 2>&1; then
    echo "[zmesh] ✓ Network zmesh-internal found (created by Docker Compose)"
else
    echo "[zmesh] WARNING: Network zmesh-internal not found"
    echo "[zmesh] Expected Docker Compose to create this network"
fi

# Verify zmesh-network exists and br-zmesh bridge is available
if docker network inspect zmesh-network >/dev/null 2>&1; then
    echo "[zmesh] ✓ Network zmesh-network found (created by Docker Compose)"
else
    echo "[zmesh] WARNING: Network zmesh-network not found"
    echo "[zmesh] Expected Docker Compose to create this network"
fi

# Verify br-zmesh bridge interface exists
if ip link show br-zmesh >/dev/null 2>&1; then
    echo "[zmesh] ✓ Bridge br-zmesh is available"
else
    echo "[zmesh] WARNING: Bridge br-zmesh not found"
    echo "[zmesh] This should be created automatically by Docker when zmesh-network is created"
fi

# Configure ZeroTier to route traffic through br-zmesh bridge
export ZEROTIER_ONE_LOCAL_PHYS="${ZEROTIER_ONE_LOCAL_PHYS:-eth0},br-zmesh"
echo "[zmesh] ZEROTIER_ONE_LOCAL_PHYS set to: $ZEROTIER_ONE_LOCAL_PHYS"

echo "[zmesh] Executing original ZeroTier entrypoint..."
exec /usr/sbin/entrypoint-router.sh "$@"
