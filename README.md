# ZeroTier SWAG Gateway

A single Docker image that combines ZeroTier network connectivity with SWAG-style Nginx reverse proxy functionality. Automatically generates reverse proxy configurations from environment variables and joins ZeroTier networks on startup.

Created by Zach Handley - [zachhandley@gmail.com](mailto:zachhandley@gmail.com) | [GitHub](https://github.com/ZachHandley) | [Website](https://zachhandley.com)

## Features

- **ZeroTier Integration**: Automatically joins ZeroTier networks for secure connectivity
- **Nginx Reverse Proxy**: SWAG-style reverse proxy with SSL support
- **Auto-Configuration**: Generates Nginx configs from simple environment variables
- **SSL Automation**: Let's Encrypt certificate management (via Certbot)
- **Single Image**: No complex multi-container setups required
- **Docker Network Support**: Service discovery via Docker networking

## Quick Start

```bash
docker run -d \
  --name zerotier-swag \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_ADMIN \
  --device=/dev/net/tun \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -e NETWORK_ID=your_zerotier_network_id \
  -e ENDPOINTS=wordpress:80,api:3000,grafana:3001 \
  -v swag_config:/config \
  zerotier-swag-gateway
```

## Environment Variables

### ZeroTier Configuration
- `NETWORK_ID` - ZeroTier network ID to join (required)

### Reverse Proxy Configuration
- `ENDPOINTS` - Comma-separated list of services to proxy (format: `service1:port1,service2:port2`)
- `DOMAINS` - Optional comma-separated list of domains (one per endpoint, in same order)

### SWAG Environment Variables
- `PUID=1000` - User ID for permissions
- `PGID=1000` - Group ID for permissions
- `TZ=Etc/UTC` - Timezone
- `URL=example.com` - Main domain for SSL certificates
- `VALIDATION=http` - Certbot validation method (http or dns)
- `SUBDOMAINS=www,` - Subdomains for SSL certificate
- `EMAIL=` - Email for certificate notifications
- `ONLY_SUBDOMAINS=false` - Only get certs for subdomains
- `EXTRA_DOMAINS=` - Additional domains for certificate
- `STAGING=false` - Use Let's Encrypt staging environment

## Examples

### Basic WordPress Setup
```bash
docker run -d \
  --name zerotier-swag \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_ADMIN \
  --device=/dev/net/tun \
  -p 80:80 -p 443:443 \
  -e NETWORK_ID=1234567890abcdef \
  -e ENDPOINTS=wordpress:80 \
  -e URL=example.com \
  -e EMAIL=admin@example.com \
  -v swag_config:/config \
  zerotier-swag-gateway
```

### Multiple Services with Custom Domains
```bash
docker run -d \
  --name zerotier-swag \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_ADMIN \
  --device=/dev/net/tun \
  -p 80:80 -p 443:443 \
  -e NETWORK_ID=1234567890abcdef \
  -e ENDPOINTS=wordpress:80,api:3000,grafana:3001 \
  -e DOMAINS=blog.example.com,api.example.com,grafana.example.com \
  -e URL=example.com \
  -e EMAIL=admin@example.com \
  -v swag_config:/config \
  zerotier-swag-gateway
```

### Docker Compose
```yaml
services:
  zerotier-swag:
    image: zerotier-swag-gateway
    container_name: zerotier-swag-gateway
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    environment:
      # SWAG Environment Variables
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - URL=example.com
      - VALIDATION=http
      - SUBDOMAINS=www,
      - EMAIL=admin@example.com

      # ZeroTier configuration
      - NETWORK_ID=your_zerotier_network_id

      # Reverse proxy endpoints
      - ENDPOINTS=wordpress:80,api:3000,grafana:3001
      - DOMAINS=blog.example.com,api.example.com,grafana.example.com
    volumes:
      - swag_config:/config
    networks:
      - backend

volumes:
  swag_config:

networks:
  backend:
    driver: bridge
```

## How It Works

1. **Startup**: Container starts and begins initialization
2. **ZeroTier**: ZeroTier daemon starts and joins the specified network
3. **Config Generation**: Parses `ENDPOINTS` environment variable and generates Nginx reverse proxy configurations
4. **SSL Setup**: Configures Let's Encrypt certificates using Certbot
5. **Nginx Start**: Starts Nginx with generated configurations

## Generated Configuration Files

The container automatically generates Nginx configuration files in `/config/nginx/proxy-confs/`:

```
/config/nginx/proxy-confs/
├── wordpress.conf
├── api.conf
└── grafana.conf
```

Each generated configuration includes proper headers for reverse proxying:
- Host header preservation
- Real IP forwarding
- SSL protocol information
- X-Forwarded headers

## Docker Capabilities Required

The container requires the following Docker capabilities for ZeroTier functionality:
- `--cap-add=NET_ADMIN` - Network administration
- `--cap-add=SYS_ADMIN` - System administration
- `--device=/dev/net/tun` - TUN device access

## Volume Structure

```
/config/
├── nginx/
│   ├── site-confs/     # Main site configurations
│   └── proxy-confs/    # Auto-generated reverse proxy configs
├── ssl/                # SSL certificates
├── dns-conf/           # DNS validation configurations
└── letsencrypt/        # Let's Encrypt data
```

## Building From Source

```bash
git clone https://github.com/ZachHandley/zerotier-caddy-gateway.git
cd zerotier-caddy-gateway
docker build -t zerotier-swag-gateway .
```

## Troubleshooting

### ZeroTier Issues
- Ensure the container has the required capabilities
- Verify the ZeroTier network ID is correct
- Check that the network is configured to allow new members

### SSL Certificate Issues
- Ensure port 80 is accessible for HTTP validation
- Verify the domain names resolve to your server
- Check DNS settings for the domains

### Proxy Configuration Issues
- Verify backend services are accessible from the container
- Check Docker network connectivity
- Review generated configuration files in `/config/nginx/proxy-confs/`

## License

This project is open source. Please refer to the LICENSE file for details.

## Support

Created by Zach Handley
- Email: [zachhandley@gmail.com](mailto:zachhandley@gmail.com)
- GitHub: [ZachHandley](https://github.com/ZachHandley)
- Website: [zachhandley.com](https://zachhandley.com)