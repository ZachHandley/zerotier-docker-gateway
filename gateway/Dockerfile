FROM bfg100k/zerotier-gateway:latest

# Install Caddy for reverse proxying
RUN apk add --no-cache caddy

# Copy config generator and custom entrypoint
COPY generate-caddyfile.sh /usr/local/bin/generate-caddyfile.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/generate-caddyfile.sh /entrypoint.sh

# Create directory for Caddy config and data
RUN mkdir -p /etc/caddy /data/caddy

ENTRYPOINT ["/entrypoint.sh"]
