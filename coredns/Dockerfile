FROM coredns/coredns:latest

# Install dependencies for DNS updater and host setup
USER root
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    util-linux  # For nsenter to restart systemd-resolved

# Copy CoreDNS configuration
COPY Corefile /etc/coredns/Corefile

# Copy scripts
COPY dns-updater.sh /usr/local/bin/dns-updater.sh
COPY setup-zmesh-dns.sh /usr/local/bin/setup-zmesh-dns.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/dns-updater.sh \
    /usr/local/bin/setup-zmesh-dns.sh \
    /entrypoint.sh

# Create data directory for zone files
RUN mkdir -p /data

# Expose DNS ports (will be mapped to 5353 on host)
EXPOSE 53/udp
EXPOSE 53/tcp

ENTRYPOINT ["/entrypoint.sh"]
