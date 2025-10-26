#!/bin/sh
# Auto-detect zmesh-network bridge interface and configure routing
echo "Starting ZeroTier router with automatic zmesh-network detection..."

# Try to detect zmesh-network bridge interface
BRIDGE_NAME=$(docker network inspect zmesh-network --format '{{.Options."com.docker.network.bridge.name"}}' 2>/dev/null || echo "")

if [ -n "$BRIDGE_NAME" ]; then
  export ZEROTIER_ONE_LOCAL_PHYS="eth0,$BRIDGE_NAME"
  echo "✓ Found zmesh-network bridge: $BRIDGE_NAME"
  echo "✓ Routing zmesh-network to ZeroTier"
else
  export ZEROTIER_ONE_LOCAL_PHYS="eth0"
  echo "⚠ Warning: zmesh-network not found, using eth0 only"
fi

# Start zerotier:router with configured interfaces
exec /usr/sbin/entrypoint-router.sh "$@"
