FROM ubuntu:24.04

# Install dependencies and add repositories
RUN apt-get update && apt-get install -y curl gnupg debian-keyring debian-archive-keyring apt-transport-https ca-certificates software-properties-common wget && rm -rf /var/lib/apt/lists/*

# Add ZeroTier repository and install ZeroTier
RUN curl -s https://install.zerotier.com | bash

# Install Docker CLI, Nginx and Certbot (SWAG-style)
RUN apt-get update && apt-get install -y docker.io nginx certbot python3-certbot-nginx fail2ban && rm -rf /var/lib/apt/lists/*

# Create SWAG-style directory structure
RUN mkdir -p /config/nginx/site-confs /config/nginx/proxy-confs /config/ssl /config/dns-conf /var/lib/zerotier-one

# Set permissions for SWAG-style user (UID 1000 may already exist)
RUN useradd -u 1001 -U -d /config -s /bin/false abc && \
    usermod -G users abc

COPY entrypoint.sh /entrypoint.sh
COPY generate-nginx-configs.sh /generate-nginx-configs.sh
RUN chmod +x /entrypoint.sh /generate-nginx-configs.sh

ENTRYPOINT ["/entrypoint.sh"]
