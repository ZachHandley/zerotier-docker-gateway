# ZeroTier Docker Gateway

Two Docker images for seamless ZeroTier integration with Docker services.

Created by Zach Handley - [zachhandley@gmail.com](mailto:zachhandley@gmail.com) | [GitHub](https://github.com/ZachHandley) | [Website](https://zachhandley.com)

## Images

### 1. Gateway (`zerotier-docker-gateway`)
Routes ZeroTier traffic to Docker containers with Caddy reverse proxy

**Base:** `bfg100k/zerotier-gateway` (Alpine Linux)
**Size:** 62.7 MB (84% smaller than original 400MB SWAG build)

### 2. CoreDNS (`zerotier-docker-gateway-dns`)
Automatic DNS discovery for ZeroTier nodes

**Base:** `coredns/coredns`
**Features:** Auto-discovers ZeroTier nodes, serves `.zmesh` DNS

## Architecture

```
Server A (Control):
├── CoreDNS Container
│   └── Auto-discovers: <nodename>.zmesh → <zerotier-ip>
├── Nginx Proxy Manager
│   └── Routes: public.domain.com → service.zmesh
└── Other control services

Server B+ (Workload):
├── Gateway Container
│   ├── ZeroTier IP: 10.147.17.x
│   ├── Routes: ZT ↔ Docker network
│   └── Caddy: Proxies to containers
├── WordPress (or any service)
├── Database
└── Other services
```

---

## Quick Start

### Gateway (Deploy on Workload Servers)

```bash
# 1. Copy example files
cd gateway/
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env

# 2. Configure .env
SITE_NAME=mysite
NETWORK_ID=your_zerotier_network_id
ENDPOINTS=wordpress:80

# 3. Start
docker-compose up -d

# 4. Get ZeroTier IP
docker exec mysite-gateway zerotier-cli listnetworks
# Note the IP (e.g., 10.147.17.5)
```

### CoreDNS (Deploy on Control Server)

```bash
# 1. Copy example files
cd coredns/
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env

# 2. Configure .env
ZEROTIER_API_KEY=your_api_key_from_my.zerotier.com
NETWORK_ID=your_zerotier_network_id

# 3. Start
docker-compose up -d

# 4. Test DNS
dig @127.0.0.1 -p 5353 mysite-gateway.zmesh
```

---

## Gateway Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NETWORK_IDS` | Yes | - | ZeroTier network ID(s), semicolon-separated |
| `GATEWAY_MODE` | Yes | - | `inbound` (ZT→Docker), `outbound` (Docker→ZT), `both` |
| `ENDPOINTS` | No | `wordpress:80` | Services to proxy: `service:port,service2:port2` |
| `DOMAINS` | No | - | Custom domains per endpoint (comma-separated) |
| `SSL_ENABLED` | No | `false` | Enable HTTPS (requires public domain) |
| `URL` | No | - | Domain for SSL |
| `EMAIL` | No | - | Email for ACME registration |

### Example docker-compose.yml

```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: mysite-wp
    networks:
      - internal
    # ... wordpress config

  db:
    image: mariadb:10.6
    networks:
      - internal
    # ... db config

  gateway:
    image: ghcr.io/zachhandley/zerotier-docker-gateway:latest
    container_name: mysite-gateway
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "80:80"
      - "443:443"
    environment:
      - NETWORK_IDS=${NETWORK_ID}
      - GATEWAY_MODE=inbound
      - ENDPOINTS=wordpress:80
    volumes:
      - zt_data:/var/lib/zerotier-one
      - caddy_data:/data/caddy
    networks:
      - internal

networks:
  internal:
    name: mysite_internal

volumes:
  zt_data:
  caddy_data:
```

---

## CoreDNS Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ZEROTIER_API_KEY` | Yes | - | API key from my.zerotier.com/account |
| `NETWORK_ID` | Yes | - | ZeroTier network ID to monitor |
| `ZTNET_URL` | No | `https://my.zerotier.com` | ZTNet URL if self-hosted |

### Example docker-compose.yml

```yaml
version: '3.8'

services:
  coredns:
    image: ghcr.io/zachhandley/zerotier-docker-gateway-dns:latest
    container_name: zerotier-dns
    privileged: true  # For host DNS configuration
    ports:
      - "5353:53/udp"  # systemd-resolved uses 53
      - "5353:53/tcp"
    environment:
      - ZEROTIER_API_KEY=${ZEROTIER_API_KEY}
      - NETWORK_ID=${NETWORK_ID}
    volumes:
      - dns_data:/data
      - /etc/systemd:/host/systemd
      - /proc:/proc:ro

volumes:
  dns_data:
```

---

## ZeroTier Central Setup

### 1. Approve Gateway Nodes

1. Go to https://my.zerotier.com
2. Select your network
3. Find gateway nodes (e.g., `mysite-gateway`)
4. Check "Authorized"

### 2. Add Managed Route (CRITICAL)

**In network settings → Managed Routes:**

Add route: `10.0.0.0/8` via `<gateway-zerotier-ip>`

This tells all ZeroTier clients to route Docker traffic through the gateway.

### 3. Note Assigned IPs

Gateways get IPs like `10.147.17.5`, `10.243.29.8`, etc.

---

## Usage Patterns

### Single Service per Gateway

Each project gets its own isolated network and gateway:

```bash
project-wp/
├── docker-compose.yml  # WordPress + DB + Gateway
└── .env               # SITE_NAME=mysite

project-grafana/
├── docker-compose.yml  # Grafana + Prometheus + Gateway
└── .env               # SITE_NAME=monitoring
```

### Multiple Endpoints in One Gateway

```yaml
gateway:
  environment:
    - ENDPOINTS=wordpress:80,phpmyadmin:80,grafana:3000
    - DOMAINS=wp.zmesh,pma.zmesh,grafana.zmesh
```

---

## How It Works

### Gateway Flow

1. Joins ZeroTier network (gets IP like 10.147.17.5)
2. Configures iptables routing between ZT ↔ Docker network
3. Generates Caddyfile from `ENDPOINTS`
4. Starts Caddy to proxy HTTP requests

### CoreDNS Flow

1. Polls ZeroTier API every 60s
2. Finds authorized nodes with names
3. Generates zone file: `<nodename>.zmesh IN A <zerotier-ip>`
4. Reloads CoreDNS every 15s
5. On first run: Configures host systemd-resolved to forward `.zmesh` → `127.0.0.1:5353`

### End-to-End Request

```
User → NPM (Server A)
  ↓
Route: blog.example.com → wp-mysite.zmesh
  ↓
CoreDNS: wp-mysite.zmesh → 10.147.17.5
  ↓
ZeroTier network routes to gateway
  ↓
Gateway iptables: ZT → Docker network
  ↓
Caddy: Reverse proxy to wordpress:80
  ↓
WordPress responds
```

---

## Building from Source

### Gateway

```bash
cd gateway/
docker build -t zerotier-docker-gateway:latest .
```

### CoreDNS

```bash
cd coredns/
docker build -t zerotier-docker-gateway-dns:latest .
```

---

## Troubleshooting

### Gateway Issues

**Won't connect to ZeroTier:**
```bash
docker exec <gateway> zerotier-cli status
docker exec <gateway> zerotier-cli listnetworks
docker logs <gateway>
```

**Can't reach services:**
```bash
# Test direct access
curl http://<zerotier-ip>

# Check iptables
docker exec <gateway> iptables -L -n -v

# Verify services on same network
docker network inspect <project>_internal
```

### CoreDNS Issues

**Not resolving:**
```bash
# Test directly
dig @127.0.0.1 -p 5353 mysite-gateway.zmesh

# Check zone file
docker exec zerotier-dns cat /data/zmesh.db

# View logs
docker logs zerotier-dns
```

**systemd-resolved not configured:**
```bash
# Check configuration
cat /etc/systemd/resolved.conf.d/zmesh.conf

# Manually restart
systemctl restart systemd-resolved

# Test resolution
resolvectl query mysite-gateway.zmesh
```

---

## License

MIT

## Credits

- Based on [bfg100k/zerotier-gateway](https://hub.docker.com/r/bfg100k/zerotier-gateway)
- Uses [Caddy](https://caddyserver.com/) for reverse proxying
- Uses [CoreDNS](https://coredns.io/) for DNS
