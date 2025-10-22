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

### HTTP-Only (Default)
```bash
docker compose up -d
```

### With SSL/HTTPS
```bash
SSL_ENABLED=true URL=yourdomain.com EMAIL=admin@yourdomain.com docker compose up -d
```

### Stop and Cleanup
```bash
# Stop services (network cleanup happens automatically)
docker compose down

# Stop services without network cleanup
ZMESH_AUTO_CLEANUP=false docker compose down
```

### Single Command Deployment
The gateway now automatically creates its Docker network on startup, so no bootstrap files or multiple compose commands are needed!

## Environment Variables

### SSL Configuration
- `SSL_ENABLED=false` - Enable SSL/HTTPS features (default: false)
- `URL=example.com` - Domain for SSL certificates (required when SSL_ENABLED=true)
- `EMAIL=admin@example.com` - Email for Let's Encrypt certificates (required when SSL_ENABLED=true)

### ZeroTier Configuration
- `NETWORK_ID` - ZeroTier network ID to join (required)

### Network Configuration
- `ZMESH_NETWORK_NAME=zmesh` - Docker network name for container communication
- `ZMESH_SUBNET=10.69.42.0/24` - Network subnet for the zmesh bridge
- `ZMESH_BRIDGE_NAME=br-zmesh` - Bridge interface name on the host
- `ZMESH_GATEWAY_IP=10.69.42.1` - Gateway IP for the bridge network
- `ZMESH_AUTO_CLEANUP=true` - Automatically cleanup network on shutdown

### Reverse Proxy Configuration
- `ENDPOINTS` - Comma-separated list of services to proxy (format: `service1:port1,service2:port2`)
- `DOMAINS` - Optional comma-separated list of domains (one per endpoint, in same order)

### Additional SWAG Variables (only used when SSL_ENABLED=true)
- `PUID=1000` - User ID for permissions
- `PGID=1000` - Group ID for permissions
- `TZ=Etc/UTC` - Timezone
- `VALIDATION=http` - Certbot validation method (http or dns)
- `SUBDOMAINS=www,` - Subdomains for SSL certificate
- `ONLY_SUBDOMAINS=false` - Only get certs for subdomains
- `EXTRA_DOMAINS=` - Additional domains for certificate
- `STAGING=false` - Use Let's Encrypt staging environment

## Examples

### HTTP-Only Gateway (Default Behavior)
```yaml
# .env file
NETWORK_ID=1234567890abcdef
ENDPOINTS=wordpress:80,api:3000
# SSL_ENABLED is false by default
```

### SSL/HTTPS Gateway
```yaml
# .env file
NETWORK_ID=1234567890abcdef
ENDPOINTS=wordpress:80,api:3000
SSL_ENABLED=true
URL=example.com
EMAIL=admin@example.com
```

### Multiple Services with Custom Domains (SSL)
```yaml
# .env file
NETWORK_ID=1234567890abcdef
ENDPOINTS=wordpress:80,api:3000,grafana:3001
DOMAINS=blog.example.com,api.example.com,grafana.example.com
SSL_ENABLED=true
URL=example.com
EMAIL=admin@example.com
```

### Complete Setup Example
```bash
# Create .env file with your configuration
cat > .env << EOF
# ZeroTier Configuration
NETWORK_ID=1234567890abcdef

# Service Configuration
ENDPOINTS=wordpress:80,api:3000

# SSL Configuration (optional)
SSL_ENABLED=false
# SSL_ENABLED=true
# URL=example.com
# EMAIL=admin@example.com

# Network Configuration (optional)
ZMESH_NETWORK_NAME=zmesh
ZMESH_SUBNET=10.69.42.0/24
ZMESH_BRIDGE_NAME=br-zmesh
ZMESH_GATEWAY_IP=10.69.42.1
ZMESH_AUTO_CLEANUP=true
EOF

# Start the gateway (creates network automatically)
docker compose up -d

# Stop with automatic network cleanup
docker compose down

# Check network status
docker network ls | grep zmesh
docker network inspect zmesh
```

### Adding Additional Services
```yaml
# docker-compose.override.yml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: unless-stopped
    environment:
      - WORDPRESS_DB_HOST=db:3306
      - WORDPRESS_DB_USER=wordpress
      - WORDPRESS_DB_PASSWORD=wordpress
      - WORDPRESS_DB_NAME=wordpress
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - zmesh

  db:
    image: mysql:5.7
    container_name: mysql
    restart: unless-stopped
    environment:
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=wordpress
      - MYSQL_PASSWORD=wordpress
      - MYSQL_ROOT_PASSWORD=root
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - zmesh

volumes:
  wordpress_data:
  db_data:

# Usage:
# docker compose -f docker-compose.yml -f docker-compose.override.yml up -d
```

## How It Works

1. **Network Bootstrap**: Gateway automatically creates the Docker bridge network if it doesn't exist
2. **ZeroTier**: ZeroTier daemon starts and joins the specified network
3. **ZeroTier IP Display**: Shows the assigned ZeroTier IP for DNS configuration
4. **SSL Check**: Evaluates `SSL_ENABLED` - if true, generates Let's Encrypt certificates
5. **Config Generation**: Parses `ENDPOINTS` environment variable and generates Nginx reverse proxy configurations (HTTP or HTTPS based on SSL_ENABLED)
6. **Validation**: Validates Nginx configuration before starting
7. **Nginx Start**: Starts Nginx with generated configurations
8. **Cleanup**: On shutdown, automatically cleans up the managed network if no other containers are using it

### Network Architecture
```
┌─────────────────────────────────────┐
│           Host Machine              │
│  ┌─────────────────────────────────┐│
│  │    zmesh (10.69.42.0/24)       ││
│  │  ┌─────┐  ┌─────┐  ┌─────┐     ││
│  │  │Gateway│ │ WP  │ │ DB  │     ││ ← All containers communicate here
│  │  └─────┘  └─────┘  └─────┘     ││
│  └─────────────────────────────────┘│
│  br-zmesh interface (10.69.42.1)    │
│                                     │
│  ZeroTier Interface (zt0)           │ ◄── External ZeroTier access
│  IP: 10.147.20.x                   │
└─────────────────────────────────────┘
```

### SSL Behavior
- **SSL_ENABLED=false (default)**: HTTP-only reverse proxy configurations
- **SSL_ENABLED=true**: Full HTTPS setup with SSL certificates, HTTP→HTTPS redirects, and security headers

### Network Cleanup
- **ZMESH_AUTO_CLEANUP=true (default)**: Automatically removes the network when gateway shuts down
- **Safety checks**: Only cleans up if no other containers are connected to the network
- **Managed networks**: Only removes networks created with the `zmesh-managed` label

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
- Ensure the container has the required capabilities (`NET_ADMIN`, `SYS_ADMIN`, `/dev/net/tun`)
- Verify the ZeroTier network ID is correct
- Check that the network is configured to allow new members
- Container will display ZeroTier IP information on startup - use this for DNS configuration

### SSL Certificate Issues
- Ensure port 80 is accessible for HTTP validation (required for Let's Encrypt)
- Verify the domain names resolve to your server's public IP
- Check DNS settings for the domains
- Ensure `SSL_ENABLED=true` with both `URL` and `EMAIL` set correctly
- Container will fall back to HTTP-only mode if SSL generation fails

### Proxy Configuration Issues
- Verify backend services are accessible from the container
- Check Docker network connectivity
- Review generated configuration files in `/config/nginx/proxy-confs`
- Container validates Nginx configuration before starting and will exit if invalid

### SSL Not Working?
- Check container logs for SSL certificate generation status
- Verify `SSL_ENABLED=true` is set and required variables (URL, EMAIL) are provided
- Ensure domain resolves correctly and port 80 is open for Let's Encrypt validation

### Network Issues?
- Check if zmesh network exists: `docker network ls | grep zmesh`
- Verify network settings: `docker network inspect zmesh`
- Check gateway container logs: `docker logs zerotier-swag-gateway`
- Manual network cleanup: `docker network rm zmesh` (if needed)
- Check container connectivity: `docker exec zerotier-swag-gateway ping wordpress`

### Network Cleanup Not Working?
- Check if other containers are using the network: `docker network inspect zmesh --format '{{len .Containers}}'`
- Verify network has zmesh-managed label: `docker network inspect zmesh --format '{{.Labels}}'`
- Force cleanup: `ZMESH_AUTO_CLEANUP=true docker compose down`

## License

This project is open source. Please refer to the LICENSE file for details.

## Support

Created by Zach Handley
- Email: [zachhandley@gmail.com](mailto:zachhandley@gmail.com)
- GitHub: [ZachHandley](https://github.com/ZachHandley)
- Website: [zachhandley.com](https://zachhandley.com)