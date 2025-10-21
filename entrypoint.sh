#!/bin/sh

echo "Starting ZeroTier..."
zerotier-one -d

# Wait for ZeroTier to be ready
echo "Waiting for ZeroTier to initialize..."
sleep 3

if [ -n "$NETWORK_ID" ]; then
  echo "Joining network: $NETWORK_ID"
  zerotier-cli join $NETWORK_ID

  # Wait for connection
  echo "Waiting for network connection..."
  sleep 5

  # Check if joined successfully
  zerotier-cli listnetworks
fi

# Generate Nginx configs from endpoints
echo "Generating Nginx configuration..."
/generate-nginx-configs.sh

# Setup nginx to include our generated configs
cat > /etc/nginx/conf.d/generated-proxies.conf << 'EOF'
# Auto-generated proxy configurations
include /config/nginx/proxy-confs/*.conf;
EOF

echo "Starting Nginx..."
# Start nginx in foreground
exec nginx -g "daemon off;"
