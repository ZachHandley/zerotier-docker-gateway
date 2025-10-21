#!/bin/sh

# Generate Nginx reverse proxy configs from environment variables
# Format: ENDPOINTS=endpoint1:port1,endpoint2:port2,endpoint3:port3
# Optional: DOMAINS=domain1,domain2,domain3 (one per endpoint)

generate_nginx_configs() {
    PROXY_CONFS_DIR=${PROXY_CONFS_DIR:-/config/nginx/proxy-confs}

    if [ -z "$ENDPOINTS" ]; then
        echo "No ENDPOINTS provided, using default reverse-proxy to wordpress:80"
        cat > "$PROXY_CONFS_DIR/default.conf" << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://wordpress:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
        return
    fi

    echo "Generating Nginx configs from endpoints..."

    # Clear existing configs
    rm -f "$PROXY_CONFS_DIR"/*.conf

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

        config_file="$PROXY_CONFS_DIR/${service_name}.conf"

        if [ -n "$domain" ] && [ "$domain" != "" ]; then
            cat > "$config_file" << EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://$service_name:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        else
            cat > "$config_file" << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://$service_name:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        fi

        echo "Generated config for $service_name:$port -> $config_file"
        counter=$((counter + 1))
    done
    IFS="$OLD_IFS"

    echo "Generated Nginx configs:"
    ls -la "$PROXY_CONFS_DIR"/*.conf
}

# Generate on startup
generate_nginx_configs