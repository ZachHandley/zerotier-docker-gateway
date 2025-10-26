#!/bin/sh

# Generate Caddyfile from environment variables
#
# PRIMARY FORMAT:
#   ENDPOINT_CONFIGS=service:port_domain,service2:port2_domain2
#   Example: ENDPOINT_CONFIGS=wordpress:80_thefunoffun.com,pma:80_pma.thefunoffun.com
#
# Optional: SSL_ENABLED=true|false (default: false)
# Optional: EMAIL=admin@example.com (for ACME registration)
# Optional: ZT_IP=10.x.x.x (binds to ZeroTier IP instead of all interfaces)

generate_caddyfile() {
    CADDYFILE_PATH=${CADDYFILE_PATH:-/etc/caddy/Caddyfile}
    SSL_ENABLED=${SSL_ENABLED:-false}

    # Determine bind address (ZeroTier IP or all interfaces)
    if [ -n "$ZT_IP" ]; then
        BIND_ADDR="${ZT_IP}"
        echo "Configuring Caddy to bind to ZeroTier IP: $BIND_ADDR"
    else
        BIND_ADDR=""
        echo "Warning: ZT_IP not set, Caddy will bind to all interfaces"
    fi

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

    # Determine which config format to use
    if [ -n "$ENDPOINT_CONFIGS" ]; then
        echo "Using new ENDPOINT_CONFIGS format..."
        CONFIG_SOURCE="ENDPOINT_CONFIGS"
        CONFIG_DATA="$ENDPOINT_CONFIGS"
    elif [ -n "$ENDPOINTS" ]; then
        echo "Using legacy ENDPOINTS format..."
        CONFIG_SOURCE="ENDPOINTS"
        CONFIG_DATA="$ENDPOINTS"
    else
        echo "No ENDPOINTS or ENDPOINT_CONFIGS provided, using default reverse-proxy to wordpress:80"

        if [ "$SSL_ENABLED" = "true" ] && [ -n "$URL" ]; then
            # HTTPS with domain
            cat >> "$CADDYFILE_PATH" << EOF
$URL {
    reverse_proxy wordpress:80
}
EOF
        else
            # HTTP only
            if [ -n "$BIND_ADDR" ]; then
                cat >> "$CADDYFILE_PATH" << EOF
${BIND_ADDR}:80 {
    reverse_proxy wordpress:80
}
EOF
            else
                cat >> "$CADDYFILE_PATH" << 'EOF'
:80 {
    reverse_proxy wordpress:80
}
EOF
            fi
        fi
        return
    fi

    echo "Generating Caddyfile from endpoints..."

    # Split endpoints by comma
    OLD_IFS="$IFS"
    IFS=","
    counter=1
    for endpoint in $CONFIG_DATA; do
        # Parse endpoint based on format
        if [ "$CONFIG_SOURCE" = "ENDPOINT_CONFIGS" ]; then
            # New format: service:port_domain
            service_port=$(echo "$endpoint" | cut -d'_' -f1)
            domain=$(echo "$endpoint" | cut -d'_' -f2)
            service_name=$(echo "$service_port" | cut -d':' -f1)
            port=$(echo "$service_port" | cut -d':' -f2)
        else
            # Legacy format: service:port
            service_name=$(echo "$endpoint" | cut -d':' -f1)
            port=$(echo "$endpoint" | cut -d':' -f2)

            # Get corresponding domain if provided
            if [ -n "$DOMAINS" ]; then
                domain=$(echo "$DOMAINS" | cut -d',' -f$counter)
            elif [ -n "$DOMAIN" ]; then
                # Fallback to single DOMAIN for all endpoints
                domain="$DOMAIN"
            else
                domain=""
            fi
        fi

        echo "Generating config for $service_name:$port (domain: ${domain:-none}, SSL: $SSL_ENABLED)"

        # Generate Caddy block with host header rewriting if domain is set
        if [ "$SSL_ENABLED" = "true" ] && [ -n "$domain" ] && [ "$domain" != "" ]; then
            # HTTPS with specific domain (Caddy auto-handles certificates)
            cat >> "$CADDYFILE_PATH" << EOF
$domain {
    reverse_proxy $service_name:$port {
        header_up Host {host}
    }
}

EOF
        elif [ "$SSL_ENABLED" = "true" ] && [ -n "$URL" ]; then
            # HTTPS with URL from env
            cat >> "$CADDYFILE_PATH" << EOF
$URL {
    reverse_proxy $service_name:$port {
        header_up Host {host}
    }
}

EOF
        elif [ -n "$domain" ] && [ "$domain" != "" ]; then
            # HTTP only with specific domain - rewrite Host header
            cat >> "$CADDYFILE_PATH" << EOF
http://$domain {
    reverse_proxy $service_name:$port {
        header_up Host $domain
    }
}

EOF
        else
            # HTTP only, listen on port 80 (ZT IP or all interfaces)
            if [ -n "$BIND_ADDR" ]; then
                cat >> "$CADDYFILE_PATH" << EOF
${BIND_ADDR}:80 {
    reverse_proxy $service_name:$port
}

EOF
            else
                cat >> "$CADDYFILE_PATH" << EOF
:80 {
    reverse_proxy $service_name:$port
}

EOF
            fi
        fi

        counter=$((counter + 1))
    done
    IFS="$OLD_IFS"

    echo "Generated Caddyfile:"
    cat "$CADDYFILE_PATH"
}

# Generate on script execution
generate_caddyfile
