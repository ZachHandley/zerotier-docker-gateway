#!/bin/sh

# Network creation function
create_network() {
    NETWORK_NAME="${ZMESH_NETWORK_NAME:-zmesh}"
    SUBNET="${ZMESH_SUBNET:-10.69.42.0/24}"
    BRIDGE_NAME="${ZMESH_BRIDGE_NAME:-br-zmesh}"
    GATEWAY_IP="${ZMESH_GATEWAY_IP:-10.69.42.1}"

    echo "=== Network Bootstrap ==="
    echo "Checking for network: $NETWORK_NAME"

    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        echo "Creating network $NETWORK_NAME ($SUBNET, $BRIDGE_NAME)"
        docker network create \
            --driver bridge \
            --subnet "$SUBNET" \
            --opt com.docker.network.bridge.name="$BRIDGE_NAME" \
            --opt com.docker.network.bridge.enable_icc=true \
            --opt com.docker.network.bridge.enable_ip_masquerade=true \
            --opt com.docker.network.bridge.gateway="$GATEWAY_IP" \
            --label zmesh-managed=true \
            "$NETWORK_NAME"

        if [ $? -eq 0 ]; then
            echo "Network $NETWORK_NAME created successfully"
        else
            echo "ERROR: Failed to create network $NETWORK_NAME"
            exit 1
        fi
    else
        echo "Network $NETWORK_NAME already exists, skipping"
    fi
    echo "========================="
}

# Network cleanup function
cleanup_network() {
    NETWORK_NAME="${ZMESH_NETWORK_NAME:-zmesh}"
    AUTO_CLEANUP="${ZMESH_AUTO_CLEANUP:-true}"

    if [ "$AUTO_CLEANUP" = "true" ] && [ -n "$NETWORK_NAME" ]; then
        echo "=== Network Cleanup ==="
        echo "Checking if network $NETWORK_NAME should be cleaned up..."

        # Check if network exists and has our label
        if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
            # Check if network has our management label
            if docker network inspect "$NETWORK_NAME" --format '{{.Labels}}' | grep -q "zmesh-managed"; then
                # Count containers connected to this network
                CONNECTED_CONTAINERS=$(docker network inspect "$NETWORK_NAME" --format '{{len .Containers}}')

                if [ "$CONNECTED_CONTAINERS" -le 1 ]; then
                    echo "Cleaning up managed network: $NETWORK_NAME"
                    docker network rm "$NETWORK_NAME" 2>/dev/null || echo "Network already removed or in use"
                else
                    echo "Network $NETWORK_NAME has $CONNECTED_CONTAINERS connected containers, skipping cleanup"
                fi
            else
                echo "Network $NETWORK_NAME is not zmesh-managed, skipping cleanup"
            fi
        else
            echo "Network $NETWORK_NAME does not exist, skipping cleanup"
        fi
        echo "======================="
    fi
}

# Setup signal handlers for graceful shutdown
trap 'echo "Caught termination signal, initiating shutdown..."; cleanup_network; exit 0' TERM INT

# First, create the Docker network
create_network

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

  # Display ZeroTier IP information for DNS configuration
  echo "=== ZeroTier Network Information ==="
  zerotier-cli info
  echo "==================================="
fi

# Handle SSL certificate generation if enabled
SSL_ENABLED=${SSL_ENABLED:-false}
if [ "$SSL_ENABLED" = "true" ]; then
    echo "SSL is enabled - checking certificate requirements..."

    if [ -z "$URL" ] || [ -z "$EMAIL" ]; then
        echo "WARNING: SSL_ENABLED=true but URL or EMAIL not provided. Falling back to HTTP-only mode."
        SSL_ENABLED="false"
    else
        echo "Generating SSL certificates for $URL..."

        # Create necessary directories
        mkdir -p /config/keys/letsencrypt /config/nginx/dhparams

        # Generate DH parameters if they don't exist
        if [ ! -f /config/nginx/dhparams.pem ]; then
            echo "Generating DH parameters (this may take a few minutes)..."
            openssl dhparam -out /config/nginx/dhparams.pem 2048
        fi

        # Generate SSL certificate using Let's Encrypt
        if [ ! -f /config/keys/letsencrypt/fullchain.pem ]; then
            echo "Requesting Let's Encrypt certificate..."
            certbot certonly --standalone \
                --email "$EMAIL" \
                --agree-tos \
                --non-interactive \
                -d "$URL" \
                --rsa-key-size 4096

            # Copy certificates to expected location
            if [ -d "/etc/letsencrypt/live/$URL" ]; then
                cp /etc/letsencrypt/live/$URL/fullchain.pem /config/keys/letsencrypt/
                cp /etc/letsencrypt/live/$URL/privkey.pem /config/keys/letsencrypt/
                echo "SSL certificate generated successfully!"
            else
                echo "ERROR: Failed to generate SSL certificate. Falling back to HTTP-only mode."
                SSL_ENABLED="false"
            fi
        else
            echo "SSL certificate already exists, skipping generation."
        fi
    fi
else
    echo "SSL is disabled - using HTTP-only configuration."
fi

# Export SSL status for config generation
export SSL_ENABLED

# Generate Nginx configs from endpoints
echo "Generating Nginx configuration..."
/generate-nginx-configs.sh

# Setup nginx to include our generated configs
cat > /etc/nginx/conf.d/generated-proxies.conf << 'EOF'
# Auto-generated proxy configurations
include /config/nginx/proxy-confs/*.conf;
EOF

# Validate nginx configuration
echo "Validating Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "Nginx configuration is valid."
    echo "Starting Nginx..."
    # Start nginx in foreground and let signal handler manage cleanup
    nginx -g "daemon off;" &
    NGINX_PID=$!

    # Wait for nginx or signal
    wait $NGINX_PID
else
    echo "ERROR: Nginx configuration validation failed!"
    exit 1
fi
