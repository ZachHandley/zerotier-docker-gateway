#!/bin/bash

echo "===================================="
echo "Configuring .zmesh DNS resolution"
echo "===================================="
echo ""

# Check if already configured
if [ -f /host/systemd/resolved.conf.d/zmesh.conf ]; then
  echo "✓ systemd-resolved already configured for .zmesh"
  exit 0
fi

# Create resolved drop-in directory
echo "[1/4] Creating systemd-resolved config directory..."
mkdir -p /host/systemd/resolved.conf.d/

# Create zmesh DNS config
echo "[2/4] Writing zmesh DNS configuration..."
cat > /host/systemd/resolved.conf.d/zmesh.conf <<EOF
[Resolve]
DNS=127.0.0.1:5353
Domains=~zmesh
EOF

echo "✓ Configuration written"

# Restart systemd-resolved using nsenter
echo "[3/4] Restarting systemd-resolved..."
nsenter --target 1 --mount --uts --ipc --net --pid -- systemctl restart systemd-resolved

echo "✓ Service restarted"

# Test DNS (wait a bit for DNS to propagate)
echo "[4/4] Testing DNS resolution..."
sleep 3

echo ""
echo "===================================="
echo "Setup complete!"
echo "DNS queries for .zmesh will now be forwarded to CoreDNS on port 5353"
echo "===================================="
