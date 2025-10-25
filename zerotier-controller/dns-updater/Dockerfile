FROM alpine:latest

# Install dependencies for DNS updater
RUN apk add --no-cache \
    curl \
    jq \
    bash

# Copy DNS updater script
COPY dns-updater.sh /usr/local/bin/dns-updater.sh
RUN chmod +x /usr/local/bin/dns-updater.sh

# Create data directory for zone files
RUN mkdir -p /data

# Create initial empty zone file
RUN cat > /data/zmesh.db << 'EOF'
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

ENTRYPOINT ["/usr/local/bin/dns-updater.sh"]
