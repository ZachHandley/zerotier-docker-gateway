#!/bin/sh
set -e

echo "[zmesh] Starting ZeroTier with zmesh bridge support..."

# Function to check if subnet is available
subnet_available() {
    local subnet="$1"
    # Check if any existing network uses this subnet
    docker network inspect $(docker network ls -q) 2>/dev/null | \
        grep -q "\"Subnet\": \"$subnet\"" && return 1 || return 0
}

# Function to create network with subnet fallback
create_network_with_subnet() {
    local network_name="$1"
    shift
    local subnets="$@"

    # Check if network already exists
    if docker network inspect "$network_name" >/dev/null 2>&1; then
        echo "[zmesh] Network $network_name already exists"
        return 0
    fi

    for subnet in $subnets; do
        if subnet_available "$subnet"; then
            echo "[zmesh] Creating $network_name with subnet $subnet..."
            if docker network create --subnet="$subnet" "$network_name" 2>/dev/null; then
                echo "[zmesh] Successfully created $network_name ($subnet)"
                return 0
            fi
        else
            echo "[zmesh] Subnet $subnet already in use, trying next..."
        fi
    done

    echo "[zmesh] ERROR: Could not create $network_name - all subnets exhausted"
    return 1
}

# Create zmesh-internal for internal service communication (CoreDNS, etc.)
# NOTE: This subnet MUST be 172.31.255.0/24 for CoreDNS static IP (172.31.255.69)
echo "[zmesh] Setting up zmesh-internal for service DNS..."
if ! docker network inspect zmesh-internal >/dev/null 2>&1; then
    if subnet_available "172.31.255.0/24"; then
        echo "[zmesh] Creating zmesh-internal with subnet 172.31.255.0/24..."
        if docker network create --subnet="172.31.255.0/24" zmesh-internal 2>/dev/null; then
            echo "[zmesh] Successfully created zmesh-internal (172.31.255.0/24)"
        else
            echo "[zmesh] ERROR: Failed to create zmesh-internal"
            echo "[zmesh] CoreDNS requires zmesh-internal with subnet 172.31.255.0/24"
            exit 1
        fi
    else
        echo "[zmesh] ERROR: Subnet 172.31.255.0/24 is already in use"
        echo "[zmesh] CoreDNS requires this specific subnet for static IP 172.31.255.69"
        echo "[zmesh] Please remove conflicting network or adjust CoreDNS configuration"
        exit 1
    fi
else
    echo "[zmesh] Network zmesh-internal already exists"
fi

# Create zmesh-network with predictable bridge name for ZeroTier routing
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
