#!/bin/sh
set -e

echo "[zmesh] Starting ZeroTier with zmesh bridge support..."

# Check if br-zmesh bridge exists
if ! ip link show br-zmesh >/dev/null 2>&1; then
    echo "[zmesh] Bridge br-zmesh not found, creating zmesh-network..."

    # Create Docker network with predictable bridge name
    if docker network create \
        --opt com.docker.network.bridge.name=br-zmesh \
        zmesh-network 2>/dev/null; then
        echo "[zmesh] Successfully created zmesh-network with bridge br-zmesh"
    else
        echo "[zmesh] Network zmesh-network already exists or creation failed (non-fatal)"
    fi

    # Verify bridge was created
    if ip link show br-zmesh >/dev/null 2>&1; then
        echo "[zmesh] Bridge br-zmesh is now available"
    else
        echo "[zmesh] WARNING: Bridge br-zmesh still not found after network creation"
    fi
else
    echo "[zmesh] Bridge br-zmesh already exists"
fi

# Always add br-zmesh to ZEROTIER_ONE_LOCAL_PHYS
export ZEROTIER_ONE_LOCAL_PHYS="${ZEROTIER_ONE_LOCAL_PHYS:-eth0},br-zmesh"
echo "[zmesh] ZEROTIER_ONE_LOCAL_PHYS set to: $ZEROTIER_ONE_LOCAL_PHYS"

echo "[zmesh] Executing original ZeroTier entrypoint..."
exec /usr/sbin/entrypoint-router.sh "$@"
