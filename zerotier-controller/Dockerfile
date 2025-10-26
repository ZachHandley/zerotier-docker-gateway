# Based on https://github.com/bfg100k/zerotier-gateway
# Extended to auto-create and route zmesh-network Docker bridge
FROM zyclonite/zerotier:router

RUN apk add --no-cache docker-cli

COPY entrypoint-zmesh.sh /usr/sbin/
RUN chmod +x /usr/sbin/entrypoint-zmesh.sh

COPY create-networks.sh /usr/local/bin/create-networks
RUN chmod +x /usr/local/bin/create-networks

ENTRYPOINT ["/usr/sbin/entrypoint-zmesh.sh"]
CMD ["-U"]
