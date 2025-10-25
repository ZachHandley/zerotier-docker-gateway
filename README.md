# ZeroTier Docker Gateway

A simple, DNS-based mesh networking solution for Docker services. No manual routes, no configuration overhead - just join and access by name.

Created by Zach Handley - [GitHub](https://github.com/ZachHandley) | [Website](https://zachhandley.com)

## What is This?

A complete mesh networking stack that lets you:
- Access Docker services across servers by name (e.g., `wordpress.zmesh`)
- Automatic service discovery - no manual IP management
- Zero manual route configuration - ZeroTier handles routing automatically
- Deploy gateways in minutes with Docker Compose

## Images

### 1. Gateway (`zerotier-docker-gateway`)
Exposes Docker services on ZeroTier network via Caddy reverse proxy

**Base:** `bfg100k/zerotier-gateway` (Alpine Linux)
**Size:** 62.7 MB (84% smaller than original 400MB SWAG build)

### 2. CoreDNS (`zerotier-docker-gateway-dns`)
Automatic DNS discovery for all ZeroTier members

**Base:** `coredns/coredns`
**Features:** Auto-discovers authorized members every 60s, serves `.zmesh` DNS

## Architecture

```
Server A (Controller + DNS):
├── ZeroTier Controller (ZTNet)
│   └── Manages network, authorizes members
├── CoreDNS Container
│   ├── Auto-discovers authorized members every 60s
│   └── Serves DNS: <hostname>.zmesh → <zerotier-ip>
├── Nginx Proxy Manager (optional)
│   └── Routes: public.domain.com → service.zmesh
└── Other control services

Server B+ (Workload Gateways):
├── Gateway Container
│   ├── Joins ZeroTier network (gets IP automatically)
│   ├── Hostname: Discoverable via DNS
│   └── Caddy: Reverse proxy to Docker services
├── WordPress (or any service)
├── Database
└── Other services

Clients:
└── Set DNS to Server A's ZeroTier IP
    └── Access services: mysite.zmesh, db.zmesh, etc.
```

## How It Works

1. **Server A** runs ZeroTier Controller + CoreDNS
2. **Gateways** join the network and expose services via Caddy
3. **CoreDNS** discovers all authorized members automatically
4. **Clients** point DNS to Server A and access services by name
5. **ZeroTier** handles all routing automatically between members

**No manual routes needed!** ZeroTier automatically routes traffic between authorized members.

---

## Key Benefits

### DNS-Based Access
- Access services by name: `mysite.zmesh`, `db.zmesh`, `grafana.zmesh`
- No IP management - CoreDNS auto-discovers everything
- Changes propagate automatically (60s polling interval)

### Zero Configuration Routing
- No manual route management in ZeroTier Central
- No subnet calculations or network planning
- ZeroTier handles all routing between authorized members automatically
- Just authorize members and they can communicate

### Simple Deployment
- One command to deploy a gateway
- Automatic service discovery
- Works across any number of servers
- Scales horizontally with zero configuration changes

### Architecture Simplification
**Old approach (complex):**
- Manual route entries for each gateway's Docker subnet
- IP tracking and documentation
- Route conflicts and debugging
- Subnet planning and coordination

**New approach (simple):**
- Deploy gateway with `SITE_NAME` and `NETWORK_ID`
- Authorize in ZTNet
- Access via `<SITE_NAME>.zmesh`
- Done!

---

## Quick Start

### Step 1: Deploy Controller + CoreDNS (Server A)

First, set up the ZeroTier network controller and DNS server:

```bash
# 1. Deploy ZTNet (ZeroTier Controller)
# Follow: https://github.com/sinamics/ztnet
# Create a network and note the NETWORK_ID

# 2. CRITICAL: Create the 'public' Docker network first
docker network create public

# 3. Deploy CoreDNS
cd coredns/
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env

# Edit .env:
ZEROTIER_API_KEY=your_api_key_from_ztnet
NETWORK_ID=your_network_id

# Start CoreDNS
docker-compose up -d

# 4. Note Server A's ZeroTier IP
docker exec zerotier-dns zerotier-cli listnetworks
# Example: 10.147.17.1
```

### Step 2: Deploy Gateways (Server B+)

Deploy gateways on each workload server:

```bash
# 1. Copy example files
cd gateway/
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env

# 2. Configure .env
SITE_NAME=mysite              # Becomes mysite.zmesh
NETWORK_ID=your_network_id
ENDPOINTS=wordpress:80        # Services to expose

# 3. Start gateway
docker-compose up -d

# 4. Authorize in ZTNet
# Go to ZTNet web UI → Network → Members
# Find "mysite" and click "Authorize"
```

### Step 3: Configure Clients

Point your DNS to Server A's ZeroTier IP:

**Linux:**
```bash
# Edit /etc/systemd/resolved.conf
[Resolve]
DNS=10.147.17.1  # Server A's ZeroTier IP
Domains=~zmesh

sudo systemctl restart systemd-resolved
```

**macOS:**
```bash
# System Preferences → Network → Advanced → DNS
# Add: 10.147.17.1
```

**Windows:**
```powershell
# Network Settings → DNS Settings
# Add: 10.147.17.1
```

### Step 4: Access Services

```bash
# Test DNS resolution
dig mysite.zmesh

# Access service
curl http://mysite.zmesh

# Or in browser
http://mysite.zmesh
```

---

## Gateway Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SITE_NAME` | Yes | - | Hostname for DNS discovery (becomes `<name>.zmesh`) |
| `NETWORK_IDS` | Yes | - | ZeroTier network ID(s), semicolon-separated |
| `GATEWAY_MODE` | Yes | `inbound` | `inbound` (ZT→Docker), `outbound` (Docker→ZT), `both` |
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
    hostname: mysite  # Important: Used for DNS discovery
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "80:80"
      - "443:443"
    environment:
      - SITE_NAME=${SITE_NAME}
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

**Key Points:**

- `hostname` must match `SITE_NAME` for DNS discovery to work
- Gateway automatically joins ZeroTier network and gets an IP
- No manual route configuration needed - ZeroTier routes between members automatically
- Services are accessed via `<SITE_NAME>.zmesh` domain

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

## ZeroTier Network Setup

### Authorize Members

After deploying gateways, authorize them in your ZeroTier controller:

**Using ZTNet:**
1. Open ZTNet web UI
2. Go to Networks → Select your network → Members
3. Find each gateway (e.g., "mysite", "db", etc.)
4. Click "Authorize"

**Using ZeroTier Central:**
1. Go to https://my.zerotier.com
2. Select your network
3. Find gateway nodes under Members
4. Check "Authorized"

**That's it!** No route configuration needed. ZeroTier automatically routes traffic between authorized members.

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

1. Gateway joins ZeroTier network
2. ZeroTier assigns an IP automatically (e.g., 10.147.17.5)
3. Gateway sets hostname from `SITE_NAME` environment variable
4. Gateway configures iptables routing between ZT ↔ Docker network
5. Gateway generates Caddyfile from `ENDPOINTS` and starts Caddy
6. Ready to serve requests!

### CoreDNS Discovery Flow

1. CoreDNS polls ZeroTier API every 60 seconds
2. Discovers all authorized members with their IPs and hostnames
3. Generates DNS zone file: `<hostname>.zmesh IN A <zerotier-ip>`
4. Reloads CoreDNS automatically
5. On first run: Configures host systemd-resolved to forward `.zmesh` → `127.0.0.1:5353`

### End-to-End Request Flow

**Direct Access (Client on ZeroTier network):**
```
Client → DNS lookup: mysite.zmesh
  ↓
CoreDNS responds: 10.147.17.5
  ↓
Client → HTTP request to 10.147.17.5
  ↓
ZeroTier routes to gateway automatically
  ↓
Gateway Caddy: Reverse proxy to wordpress:80
  ↓
WordPress responds
```

**Public Access (via Nginx Proxy Manager):**
```
Internet → blog.example.com
  ↓
NPM (Server A) → Proxies to mysite.zmesh
  ↓
CoreDNS: mysite.zmesh → 10.147.17.5
  ↓
ZeroTier routes to gateway
  ↓
Gateway Caddy → wordpress:80
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

**Gateway won't connect to ZeroTier:**
```bash
# Check ZeroTier status
docker exec <gateway> zerotier-cli status

# List networks and IPs
docker exec <gateway> zerotier-cli listnetworks

# View gateway logs
docker logs <gateway>
```

**Solution:** Make sure the gateway is authorized in ZTNet/ZeroTier Central.

**Can't reach services:**
```bash
# Test DNS resolution first
dig mysite.zmesh

# Test direct IP access
curl http://<zerotier-ip>

# Check Caddy is running
docker exec <gateway> caddy version

# Check iptables
docker exec <gateway> iptables -L -n -v

# Verify services on same Docker network
docker network inspect <project>_internal
```

**Solution:** Ensure `ENDPOINTS` is configured correctly and services are on the same Docker network as gateway.

### CoreDNS Issues

**DNS not resolving:**
```bash
# Test CoreDNS directly (bypass systemd-resolved)
dig @127.0.0.1 -p 5353 mysite.zmesh

# Check if zone file has entries
docker exec zerotier-dns cat /data/zmesh.db

# View CoreDNS logs
docker logs zerotier-dns

# Check if members are authorized
# (CoreDNS only discovers AUTHORIZED members)
```

**Solution:** Make sure gateways are authorized in ZTNet and have hostnames set.

**systemd-resolved not forwarding .zmesh queries:**
```bash
# Check if zmesh config exists
cat /etc/systemd/resolved.conf.d/zmesh.conf

# Should show:
# [Resolve]
# DNS=127.0.0.1:5353
# Domains=~zmesh

# Restart resolver
sudo systemctl restart systemd-resolved

# Test resolution
resolvectl query mysite.zmesh
```

**Solution:** Restart CoreDNS container - it auto-configures systemd-resolved on first run.

### Common Issues

**"No route to host" when accessing .zmesh domains:**

This means ZeroTier routing is working (DNS resolved), but gateway isn't reachable.

Check:
1. Is gateway authorized in ZTNet?
2. Is client on the ZeroTier network?
3. Is gateway container running?

```bash
# On client machine, verify ZeroTier connection
zerotier-cli listnetworks

# Should show ONLINE and an IP assigned
```

**DNS resolves but HTTP times out:**

Gateway is reachable but Caddy isn't proxying correctly.

Check:
1. Is `ENDPOINTS` configured?
2. Are backend services running?
3. Are backend services on same Docker network?

```bash
# Check Caddy config
docker exec <gateway> cat /etc/caddy/Caddyfile

# Test backend directly from gateway
docker exec <gateway> wget -O- http://wordpress:80
```

---

## Frequently Asked Questions

### Do I need to configure routes in ZeroTier Central?

**No!** ZeroTier automatically routes traffic between all authorized members. You only need to:
1. Deploy gateway
2. Authorize in ZTNet
3. Access via DNS

The old approach required manual route entries for each gateway's Docker subnet. That's completely eliminated now.

### How does DNS discovery work?

CoreDNS polls the ZeroTier API every 60 seconds and discovers all authorized members that have a hostname set. It automatically generates DNS records:

```
mysite.zmesh    → 10.147.17.5
database.zmesh  → 10.147.17.8
grafana.zmesh   → 10.147.17.12
```

### What if I add a new gateway?

Just deploy it with a unique `SITE_NAME` and authorize it in ZTNet. Within 60 seconds, CoreDNS will discover it and create the DNS record. No other configuration needed.

### Can I use this with ZeroTier Central (not ZTNet)?

Yes! The architecture works with both:
- **ZTNet (self-hosted)**: Full control, recommended for production
- **ZeroTier Central (my.zerotier.com)**: Easier to get started, cloud-hosted

Just set the API key from your chosen platform.

### What happens if Server A (DNS) goes down?

You can still access services by IP if you know them. Or deploy a secondary CoreDNS instance on another server with the same configuration for redundancy.

### Do all gateways need to be on different servers?

No! You can run multiple gateways on the same server. Each gets its own ZeroTier IP and unique hostname. Just make sure they use different port mappings or run on different Docker networks.

### How do I expose services to the public internet?

Use Nginx Proxy Manager (or any reverse proxy) on Server A:
1. Point DNS `blog.example.com` to Server A's public IP
2. In NPM, create proxy host: `blog.example.com` → `http://mysite.zmesh`
3. NPM resolves via CoreDNS, routes over ZeroTier to gateway

### Can clients outside the ZeroTier network access services?

Not directly - they need to either:
1. Join the ZeroTier network as a client
2. Access via public reverse proxy (NPM) on Server A
3. Use ZeroTier's network bridging features

---

## License

MIT

## Credits

- Based on [bfg100k/zerotier-gateway](https://hub.docker.com/r/bfg100k/zerotier-gateway)
- Uses [Caddy](https://caddyserver.com/) for reverse proxying
- Uses [CoreDNS](https://coredns.io/) for DNS
