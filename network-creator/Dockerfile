FROM docker:cli
COPY create-networks.sh /create-networks.sh
RUN chmod +x /create-networks.sh
ENTRYPOINT ["/bin/sh", "/create-networks.sh"]
