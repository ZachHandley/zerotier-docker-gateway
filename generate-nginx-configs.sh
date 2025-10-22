#!/bin/sh

# Generate Nginx reverse proxy configs from environment variables
# Format: ENDPOINTS=endpoint1:port1,endpoint2:port2,endpoint3:port3
# Optional: DOMAINS=domain1,domain2,domain3 (one per endpoint)

generate_nginx_configs() {
    PROXY_CONFS_DIR=${PROXY_CONFS_DIR:-/config/nginx/proxy-confs}
    SSL_ENABLED=${SSL_ENABLED:-false}

    if [ -z "$ENDPOINTS" ]; then
        echo "No ENDPOINTS provided, using default reverse-proxy to wordpress:80"

        if [ "$SSL_ENABLED" = "true" ] && [ -n "$URL" ] && [ -n "$EMAIL" ]; then
            echo "Generating SSL-enabled config for default endpoint..."
            cat > "$PROXY_CONFS_DIR/default.conf" << EOF
server {
    listen 80;
    server_name $URL;

    # Redirect HTTP to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $URL;

    # SSL Configuration
    ssl_certificate /config/keys/letsencrypt/fullchain.pem;
    ssl_certificate_key /config/keys/letsencrypt/privkey.pem;
    ssl_dhparam /config/nginx/dhparams.pem;

    # SSL Headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy no-referrer-when-downgrade always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        proxy_pass http://wordpress:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-SSL on;
    }
}
EOF
        else
            echo "Generating HTTP-only config for default endpoint..."
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
        fi
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

        if [ "$SSL_ENABLED" = "true" ] && [ -n "$URL" ] && [ -n "$EMAIL" ]; then
            echo "Generating SSL-enabled config for $service_name:$port"

            # Use domain if provided, otherwise use main URL with path
            if [ -n "$domain" ] && [ "$domain" != "" ]; then
                server_domain="$domain"
            else
                server_domain="$URL"
            fi

            cat > "$config_file" << EOF
server {
    listen 80;
    server_name $server_domain;

    # Redirect HTTP to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $server_domain;

    # SSL Configuration
    ssl_certificate /config/keys/letsencrypt/fullchain.pem;
    ssl_certificate_key /config/keys/letsencrypt/privkey.pem;
    ssl_dhparam /config/nginx/dhparams.pem;

    # SSL Headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy no-referrer-when-downgrade always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    location / {
        proxy_pass http://$service_name:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-SSL on;
    }
}
EOF
        else
            echo "Generating HTTP-only config for $service_name:$port"

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