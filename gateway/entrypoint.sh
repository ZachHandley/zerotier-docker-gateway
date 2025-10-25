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
