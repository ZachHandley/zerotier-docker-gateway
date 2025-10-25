#!/bin/sh

# Generate Caddyfile from environment variables
# Format: ENDPOINTS=service1:port1,service2:port2,service3:port3
# Optional: DOMAINS=domain1,domain2,domain3 (one per endpoint)
# Optional: SSL_ENABLED=true|false (default: false)
# Optional: EMAIL=admin@example.com (for ACME registration)

generate_caddyfile() {
    CADDYFILE_PATH=${CADDYFILE_PATH:-/etc/caddy/Caddyfile}
    SSL_ENABLED=${SSL_ENABLED:-false}

    # Start Caddyfile with global options
    cat > "$CADDYFILE_PATH" << 'EOF'
# Auto-generated Caddyfile
# Generated from ENDPOINTS environment variable

EOF

    # Add email for ACME if provided and SSL enabled
    if [ "$SSL_ENABLED" = "true" ] && [ -n "$EMAIL" ]; then
        cat >> "$CADDYFILE_PATH" << EOF
{
    email $EMAIL
}

EOF
    fi

    if [ -z "$ENDPOINTS" ]; then
        echo "No ENDPOINTS provided, using default reverse-proxy to wordpress:80"

        if [ "$SSL_ENABLED" = "true" ] && [ -n "$URL" ]; then
            # HTTPS with domain
            cat >> "$CADDYFILE_PATH" << EOF
$URL {
    reverse_proxy wordpress:80
}
EOF
        else
            # HTTP only
            cat >> "$CADDYFILE_PATH" << 'EOF'
:80 {
    reverse_proxy wordpress:80
}
EOF
        fi
        return
    fi

    echo "Generating Caddyfile from endpoints..."

    # Split endpoints by comma
    OLD_IFS="$IFS"
    IFS=","
    counter=1
    for endpoint in $ENDPOINTS; do
        # Split endpoint by colon
        service_name=$(echo "$endpoint" | cut -d':' -f1)
        port=$(echo "$endpoint" | cut -d':' -f2)

        # Get corresponding domain if provided
        if [ -n "$DOMAINS" ]; then
            domain=$(echo "$DOMAINS" | cut -d',' -f$counter)
        else
            domain=""
        fi

        echo "Generating config for $service_name:$port (SSL: $SSL_ENABLED)"

        # Generate Caddy block
        if [ "$SSL_ENABLED" = "true" ] && [ -n "$domain" ] && [ "$domain" != "" ]; then
            # HTTPS with specific domain (Caddy auto-handles certificates)
            cat >> "$CADDYFILE_PATH" << EOF
$domain {
    reverse_proxy $service_name:$port
}

EOF
        elif [ "$SSL_ENABLED" = "true" ] && [ -n "$URL" ]; then
            # HTTPS with URL from env
            cat >> "$CADDYFILE_PATH" << EOF
$URL {
    reverse_proxy $service_name:$port
}

EOF
        elif [ -n "$domain" ] && [ "$domain" != "" ]; then
            # HTTP only with specific domain
            cat >> "$CADDYFILE_PATH" << EOF
http://$domain {
    reverse_proxy $service_name:$port
}

EOF
        else
            # HTTP only, listen on all requests on port 80
            cat >> "$CADDYFILE_PATH" << EOF
:80 {
    reverse_proxy $service_name:$port
}

EOF
        fi

        counter=$((counter + 1))
    done
    IFS="$OLD_IFS"

    echo "Generated Caddyfile:"
    cat "$CADDYFILE_PATH"
}

# Generate on script execution
generate_caddyfile
