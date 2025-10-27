#!/bin/bash

# Wrapper entrypoint that combines ZeroTier Gateway + Caddy

# Trap signals for graceful shutdown
cleanup() {
    echo "Shutting down..."
    if [ -n "$CADDY_PID" ]; then
        kill -TERM $CADDY_PID 2>/dev/null
    fi
    if [ -n "$ZT_PID" ]; then
        kill -TERM $ZT_PID 2>/dev/null
    fi
    exit 0
}

trap 'cleanup' SIGTERM SIGINT

echo "=== Starting ZeroTier + Caddy Gateway ==="

# Handle network IDs - support both NETWORK_IDS and NETWORK_ID variables
# The base zerotier-gateway image expects ZEROTIER_ONE_NETWORK_IDS
if [ -n "$NETWORK_IDS" ]; then
    export ZEROTIER_ONE_NETWORK_IDS="$NETWORK_IDS"
    echo "Using NETWORK_IDS: $NETWORK_IDS"
elif [ -n "$NETWORK_ID" ]; then
    export ZEROTIER_ONE_NETWORK_IDS="$NETWORK_ID"
    echo "Using NETWORK_ID: $NETWORK_ID"
else
    echo "WARNING: No NETWORK_IDS or NETWORK_ID specified. Gateway will not auto-join any networks."
fi

if [ -n "$ZEROTIER_ONE_NETWORK_IDS" ]; then
    echo "ZeroTier will auto-join network(s): $ZEROTIER_ONE_NETWORK_IDS"
fi

# Download custom planet file from ZTNet if configured
if [ -n "$ZTNET_URL" ] && [ -n "$ZERO_API_KEY" ]; then
    PLANET_FILE="/var/lib/zerotier-one/planet"
    PLANET_URL="${ZTNET_URL}/api/planet"
    PLANET_TEMP="/tmp/planet.new"

    # Download to temp location first
    echo "Checking for ZTNet planet file updates..."
    curl -sSf -H "X-ZTNet-API-Key: ${ZERO_API_KEY}" \
         -o "$PLANET_TEMP" \
         "${PLANET_URL}"

    if [ $? -eq 0 ]; then
        # Check if planet file exists and compare
        if [ -f "$PLANET_FILE" ]; then
            OLD_HASH=$(md5sum "$PLANET_FILE" | cut -d' ' -f1)
            NEW_HASH=$(md5sum "$PLANET_TEMP" | cut -d' ' -f1)

            if [ "$OLD_HASH" = "$NEW_HASH" ]; then
                echo "✓ Planet file is up to date (skipping download)"
                rm "$PLANET_TEMP"
            else
                mv "$PLANET_TEMP" "$PLANET_FILE"
                echo "✓ Planet file updated (changed from previous version)"
            fi
        else
            mv "$PLANET_TEMP" "$PLANET_FILE"
            echo "✓ Custom planet file installed"
        fi
    else
        echo "✗ Failed to download planet file"
        if [ ! -f "$PLANET_FILE" ]; then
            echo "  WARNING: No planet file available - using public ZeroTier"
        else
            echo "  Using existing planet file"
        fi
        rm -f "$PLANET_TEMP"
    fi
elif [ -n "$ZTNET_URL" ] || [ -n "$ZERO_API_KEY" ]; then
    echo "⚠ WARNING: Both ZTNET_URL and ZERO_API_KEY must be set to use custom ZTNet controller"
fi

# Start ZeroTier gateway in the background
echo "Starting ZeroTier gateway..."
/usr/sbin/main.sh &
export ZT_PID=$!

# Wait for ZeroTier to be ready
echo "Waiting for ZeroTier to initialize..."
RETRY_COUNT=10
SLEEP_TIME=3
TRY_COUNT=0

while [ $TRY_COUNT -lt $RETRY_COUNT ]; do
    sleep $SLEEP_TIME
    if zerotier-cli status 2>/dev/null | grep -q "ONLINE"; then
        echo "ZeroTier is ONLINE!"
        break
    fi
    TRY_COUNT=$((TRY_COUNT + 1))
    if [ $TRY_COUNT -eq $RETRY_COUNT ]; then
        echo "ERROR: ZeroTier failed to come online"
        exit 1
    fi
    echo "Waiting for ZeroTier... (attempt $TRY_COUNT/$RETRY_COUNT)"
done

# Display ZeroTier network info
echo "=== ZeroTier Status ==="
zerotier-cli info
echo ""

# Explicitly join networks (don't rely on base image)
if [ -n "$ZEROTIER_ONE_NETWORK_IDS" ]; then
    echo "=== Joining ZeroTier Networks ==="
    IFS=';' read -ra NETWORK_ARRAY <<< "$ZEROTIER_ONE_NETWORK_IDS"
    for network_id in "${NETWORK_ARRAY[@]}"; do
        network_id=$(echo "$network_id" | xargs) # trim whitespace
        echo "Joining network: $network_id..."
        zerotier-cli join "$network_id"
        sleep 2  # Give it a moment to process
    done
    echo ""
fi

echo "=== Joined Networks ==="
zerotier-cli listnetworks
echo ""

# Verify network join if ZEROTIER_ONE_NETWORK_IDS was set
if [ -n "$ZEROTIER_ONE_NETWORK_IDS" ]; then
    echo "=== Verifying Network Join ==="
    IFS=';' read -ra NETWORK_ARRAY <<< "$ZEROTIER_ONE_NETWORK_IDS"
    for network_id in "${NETWORK_ARRAY[@]}"; do
        network_id=$(echo "$network_id" | xargs) # trim whitespace
        if zerotier-cli listnetworks | grep -q "$network_id"; then
            echo "✓ Successfully joined network: $network_id"
        else
            echo "✗ WARNING: Failed to join network: $network_id"
            echo "  Check that the network exists and gateway is authorized"
        fi
    done
    echo ""
fi

# Detect ZeroTier IP for Caddy to bind to
echo "Detecting ZeroTier IP address..."
ZT_IP=$(zerotier-cli listnetworks | grep OK | awk '{print $9}' | cut -d'/' -f1)

if [ -z "$ZT_IP" ]; then
    echo "ERROR: Could not detect ZeroTier IP address"
    echo "Network may not be fully ready or authorized"
    exit 1
fi

echo "ZeroTier IP detected: $ZT_IP"
export ZT_IP

# Display DNS setup instructions
echo ""
echo "========================================="
echo "Gateway Configuration:"
echo "  Service: ${SITE_NAME}.zmesh"
echo "  ZeroTier IP: ${ZT_IP}"
echo ""
echo "Client Setup (choose one):"
echo "  1. Add to /etc/hosts:"
echo "     ${ZT_IP}  ${SITE_NAME}.zmesh"
echo ""
echo "  2. Use CoreDNS on Server A (auto-discovery)"
echo "  3. Use zt2hosts.sh for auto-discovery"
echo "========================================="
echo ""

# Generate Caddyfile from environment variables
echo "Generating Caddy configuration..."
/usr/local/bin/generate-caddyfile.sh

if [ ! -f /etc/caddy/Caddyfile ]; then
    echo "ERROR: Failed to generate Caddyfile"
    exit 1
fi

# Start Caddy in foreground
echo "Starting Caddy reverse proxy..."
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
export CADDY_PID=$!

echo "=== Gateway is ready! ==="
echo "ZeroTier PID: $ZT_PID"
echo "Caddy PID: $CADDY_PID"

# Wait for Caddy (primary service)
wait $CADDY_PID
exit_code=$?

echo "Caddy exited with code $exit_code"
exit $exit_code
