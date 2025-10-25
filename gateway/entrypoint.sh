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
zerotier-cli info
zerotier-cli listnetworks

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
