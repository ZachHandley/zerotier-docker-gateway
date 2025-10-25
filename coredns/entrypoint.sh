#!/bin/bash

# Entrypoint for ZeroTier CoreDNS Auto-Discovery

set -e

echo "=== ZeroTier CoreDNS Auto-Discovery Starting ==="

# Validate required environment variables
if [ -z "$ZEROTIER_API_KEY" ]; then
    echo "ERROR: ZEROTIER_API_KEY environment variable is required"
    exit 1
fi

if [ -z "$NETWORK_ID" ]; then
    echo "ERROR: NETWORK_ID environment variable is required"
    exit 1
fi

# Set default ZTNET_URL if not provided
export ZTNET_URL=${ZTNET_URL:-https://my.zerotier.com}

echo "Configuration:"
echo "  ZTNET_URL: $ZTNET_URL"
echo "  NETWORK_ID: $NETWORK_ID"
echo ""

# Setup host systemd-resolved (if host volume is mounted)
if [ -d "/host/systemd" ]; then
    echo "Checking host DNS configuration..."
    /usr/local/bin/setup-zmesh-dns.sh || echo "⚠ Could not configure host DNS (may require privileged mode)"
    echo ""
else
    echo "⚠ /host/systemd not mounted - skipping host DNS setup"
    echo "  To auto-configure host DNS, add volume: /etc/systemd:/host/systemd"
    echo ""
fi

# Create initial empty zone file if it doesn't exist
if [ ! -f /data/zmesh.db ]; then
    echo "Creating initial zone file..."
    cat > /data/zmesh.db << 'EOF'
$TTL 60
$ORIGIN zmesh.
@   IN SOA ns.zmesh. admin.zmesh. (
        2025010100
        3600
        1800
        604800
        60 )
    IN NS ns.zmesh.
EOF
fi

# Start DNS updater in background
echo "Starting DNS updater service..."
/usr/local/bin/dns-updater.sh &
DNS_UPDATER_PID=$!

# Trap signals for graceful shutdown
cleanup() {
    echo "Shutting down..."
    kill -TERM $DNS_UPDATER_PID 2>/dev/null || true
    kill -TERM $COREDNS_PID 2>/dev/null || true
    exit 0
}

trap 'cleanup' SIGTERM SIGINT

# Wait a moment for first DNS update
sleep 3

# Start CoreDNS in foreground
echo "Starting CoreDNS..."
echo "=== CoreDNS is ready on port 53 (map to 5353 on host) ==="
/coredns -conf /etc/coredns/Corefile &
COREDNS_PID=$!

# Wait for CoreDNS
wait $COREDNS_PID
exit_code=$?

echo "CoreDNS exited with code $exit_code"
exit $exit_code
