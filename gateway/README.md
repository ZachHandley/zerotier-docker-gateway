# ZeroTier Docker Gateway with DNS-Based Service Discovery

A lightweight, DNS-based gateway that seamlessly connects ZeroTier networks to Docker containers using Caddy reverse proxy.

## Key Features

- **DNS-Based Discovery**: Services are accessible via `<service-name>.zmesh` domain
- **ZeroTier IP Binding**: Caddy binds directly to the ZeroTier interface (not all interfaces)
- **Automatic Configuration**: No manual route management required
- **Lightweight**: Only 62.7 MB (Alpine-based)
- **Multiple Client Options**: Choose the DNS setup that fits your workflow

## Architecture Overview

```
Client (Laptop/Desktop)
  |
  | DNS: mysite.zmesh → 10.147.17.5
  |
ZeroTier Network (10.x.x.x)
  |
  v
Gateway Container (10.147.17.5)
  ├── ZeroTier Interface: ztxxxxxxxx
  ├── Caddy (bound to 10.147.17.5:80)
  └── Routes to Docker Network (172.x.x.x)
      |
      ├── WordPress (wordpress:80)
      ├── MariaDB (db:3306)
      └── Other Services
```

## How It Works

1. **Gateway Joins ZeroTier Network**
   - Gets assigned a ZeroTier IP (e.g., 10.147.17.5)
   - Automatically configures routing between ZeroTier and Docker networks

2. **Caddy Binds to ZeroTier IP**
   - Listens ONLY on the ZeroTier interface (not 0.0.0.0)
   - No exposure to public internet or other interfaces

3. **DNS-Based Service Discovery**
   - Service name: `${SITE_NAME}.zmesh`
   - Gateway logs show the ZeroTier IP at startup
   - Clients resolve the domain to the gateway's ZT IP

4. **Automatic Routing**
   - ZeroTier automatically routes traffic to member IPs
   - No manual route configuration needed in ZeroTier Central

## Quick Start

### 1. Prepare Configuration Files

```bash
cd gateway/
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env
```

### 2. Edit `.env` File

```bash
# Required: Unique name for this deployment
SITE_NAME=mysite

# Required: Your ZeroTier Network ID
# Get this from https://my.zerotier.com
NETWORK_ID=abc123def456

# Required: Services to expose
ENDPOINTS=wordpress:80

# Optional: Multiple services
# ENDPOINTS=wordpress:80,phpmyadmin:80
# DOMAINS=wp.zmesh,pma.zmesh

# SSL Configuration (keep false for ZeroTier-only)
SSL_ENABLED=false
```

### 3. Start the Gateway

```bash
docker-compose up -d
```

### 4. Get Gateway Information

```bash
# View startup logs for ZeroTier IP
docker logs mysite-gateway

# Or check directly
docker exec mysite-gateway zerotier-cli listnetworks
```

You'll see output like:
```
=========================================
Gateway Configuration:
  Service: mysite.zmesh
  ZeroTier IP: 10.147.17.5

Client Setup (choose one):
  1. Add to /etc/hosts:
     10.147.17.5  mysite.zmesh

  2. Use CoreDNS on Server A (auto-discovery)
  3. Use zt2hosts.sh for auto-discovery
=========================================
```

### 5. Authorize in ZeroTier Central

1. Go to https://my.zerotier.com
2. Select your network
3. Find the new member (e.g., `mysite-gateway`)
4. Check "Authorized"

### 6. Configure Client DNS

Choose one of the three options below.

---

## Client Setup Options

### Option 1: Manual /etc/hosts Entry (Simplest)

**Best for:** Single services, testing, or when you don't want DNS complexity

Add the gateway to your hosts file:

**Linux/Mac:**
```bash
sudo nano /etc/hosts

# Add this line (use the IP from gateway logs):
10.147.17.5  mysite.zmesh
```

**Windows:**
```powershell
# Run as Administrator
notepad C:\Windows\System32\drivers\etc\hosts

# Add this line:
10.147.17.5  mysite.zmesh
```

**Pros:**
- Simple and straightforward
- Works immediately
- No additional services needed

**Cons:**
- Manual update required for each service
- Need to update if gateway IP changes

---

### Option 2: CoreDNS on Server A (Automatic Discovery)

**Best for:** Multiple services, dynamic environments, production use

Deploy CoreDNS on your control server (Server A) to automatically discover all ZeroTier services.

#### Deploy CoreDNS

```bash
cd coredns/
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env

# Configure .env
nano .env
```

```bash
# CoreDNS Configuration
ZEROTIER_API_KEY=your_api_key_from_my.zerotier.com
NETWORK_ID=your_zerotier_network_id
```

```bash
# Start CoreDNS
docker-compose up -d
```

#### Configure Your Client

**Get Server A's ZeroTier IP:**
```bash
# On Server A
zerotier-cli listnetworks
# Note the IP (e.g., 10.147.17.1)
```

**Configure DNS on Client:**

**Linux (systemd-resolved):**
```bash
sudo nano /etc/systemd/resolved.conf

[Resolve]
DNS=10.147.17.1
Domains=~zmesh
```

```bash
sudo systemctl restart systemd-resolved
```

**Mac:**
```bash
# System Settings → Network → Advanced → DNS
# Add: 10.147.17.1
```

**Windows:**
```powershell
# Network Adapter Settings → TCP/IPv4 Properties
# Set DNS Server to: 10.147.17.1
```

#### Test DNS Resolution

```bash
# Linux/Mac
dig mysite.zmesh

# Windows
nslookup mysite.zmesh
```

**Pros:**
- Automatic service discovery
- No manual updates needed
- Works for all services automatically

**Cons:**
- Requires running CoreDNS server
- Slightly more complex setup

---

### Option 3: zt2hosts.sh Script (Semi-Automatic)

**Best for:** Local development, multiple services, no dedicated DNS server

Use the included script to automatically update your /etc/hosts file.

#### Setup

```bash
# Download the script (from coredns directory)
curl -O https://raw.githubusercontent.com/zachhandley/zerotier-caddy-gateway/main/coredns/zt2hosts.sh
chmod +x zt2hosts.sh

# Configure
export ZEROTIER_API_KEY=your_api_key
export NETWORK_ID=your_network_id
```

#### Manual Update

```bash
sudo ./zt2hosts.sh
```

#### Automatic Updates (Optional)

```bash
# Add to crontab for automatic updates every 5 minutes
sudo crontab -e

# Add this line:
*/5 * * * * /path/to/zt2hosts.sh
```

#### What It Does

1. Queries ZeroTier API for all authorized members
2. Finds members with names (e.g., `mysite-gateway`)
3. Updates `/etc/hosts` with entries:
   ```
   10.147.17.5  mysite-gateway.zmesh mysite.zmesh
   10.147.17.8  monitoring-gateway.zmesh monitoring.zmesh
   ```

**Pros:**
- Automatic discovery like CoreDNS
- No dedicated server required
- Works offline after initial sync

**Cons:**
- Requires periodic updates (manual or cron)
- Needs API key
- Root/admin access required

---

## Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SITE_NAME` | Unique identifier for this deployment | `mysite` |
| `NETWORK_ID` | ZeroTier Network ID from my.zerotier.com | `abc123def456` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENDPOINTS` | `wordpress:80` | Services to proxy (format: `service:port,service2:port2`) |
| `DOMAINS` | - | Custom domains per endpoint (comma-separated) |
| `SSL_ENABLED` | `false` | Enable HTTPS (requires public domain) |
| `DOMAIN` | - | Domain name for SSL |
| `EMAIL` | - | Email for ACME/Let's Encrypt registration |

### Example Configurations

#### Single Service (Default)

```bash
SITE_NAME=myblog
NETWORK_ID=abc123def456
ENDPOINTS=wordpress:80
```

Access: `http://myblog.zmesh`

#### Multiple Services

```bash
SITE_NAME=myservices
NETWORK_ID=abc123def456
ENDPOINTS=wordpress:80,phpmyadmin:80,grafana:3000
DOMAINS=blog.zmesh,pma.zmesh,monitoring.zmesh
```

Access:
- `http://blog.zmesh` → WordPress
- `http://pma.zmesh` → phpMyAdmin
- `http://monitoring.zmesh` → Grafana

#### With SSL (Public Domain)

```bash
SITE_NAME=myblog
NETWORK_ID=abc123def456
ENDPOINTS=wordpress:80
SSL_ENABLED=true
DOMAIN=blog.example.com
EMAIL=admin@example.com
```

**Note:** SSL requires a public domain with DNS pointing to a public IP. For ZeroTier-only access, keep `SSL_ENABLED=false`.

---

## How DNS Resolution Works

### DNS Hierarchy

```
Client Request: http://mysite.zmesh
  |
  v
DNS Resolution: mysite.zmesh → 10.147.17.5
  |
  ├─ Option 1: /etc/hosts file
  ├─ Option 2: CoreDNS Server (10.147.17.1:53)
  └─ Option 3: zt2hosts.sh script
  |
  v
ZeroTier Network Routes to: 10.147.17.5
  |
  v
Gateway Caddy (bound to 10.147.17.5:80)
  |
  v
Reverse Proxy to: wordpress:80 (172.18.0.2)
```

### Why .zmesh Domain?

- **Private TLD**: `.zmesh` is not a real internet TLD
- **No Conflicts**: Won't clash with public domains
- **Clear Intent**: Immediately identifies ZeroTier mesh services
- **Convention**: Follows mesh network naming patterns

---

## Advanced Configuration

### Custom Caddyfile

If you need more complex Caddy configuration, you can mount a custom Caddyfile:

```yaml
gateway:
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile:ro
    - caddy_data:/data/caddy
```

### Multiple Networks

```yaml
gateway:
  environment:
    - NETWORK_IDS=network1;network2;network3
```

### Custom Network Interface

By default, the gateway auto-detects interfaces. Override if needed:

```yaml
gateway:
  environment:
    - LO_DEV=eth0      # Docker bridge interface
    - ZT_DEV=ztxxxxxxx  # ZeroTier interface name
```

---

## Troubleshooting

### Gateway Won't Start

**Check ZeroTier status:**
```bash
docker logs mysite-gateway
docker exec mysite-gateway zerotier-cli status
```

**Common issues:**
- Not authorized in ZeroTier Central
- Invalid `NETWORK_ID`
- Missing required capabilities (`NET_ADMIN`, `SYS_ADMIN`)

### Can't Access Services

**1. Verify ZeroTier connectivity:**
```bash
# From client, ping gateway
ping 10.147.17.5
```

**2. Test DNS resolution:**
```bash
# Should return the ZeroTier IP
nslookup mysite.zmesh
```

**3. Test direct HTTP access:**
```bash
# Skip DNS, use IP directly
curl http://10.147.17.5
```

**4. Check Caddy is running:**
```bash
docker exec mysite-gateway ps aux | grep caddy
```

**5. View Caddy configuration:**
```bash
docker exec mysite-gateway cat /etc/caddy/Caddyfile
```

### DNS Not Resolving

**Option 1 (Manual /etc/hosts):**
```bash
# Verify entry exists
cat /etc/hosts | grep zmesh

# Try adding IP directly to browser
http://10.147.17.5
```

**Option 2 (CoreDNS):**
```bash
# Test CoreDNS directly
dig @10.147.17.1 mysite.zmesh

# Check CoreDNS logs
docker logs zerotier-dns

# Verify zone file
docker exec zerotier-dns cat /data/zmesh.db
```

**Option 3 (zt2hosts.sh):**
```bash
# Re-run script
sudo ./zt2hosts.sh

# Check /etc/hosts
cat /etc/hosts | grep zmesh
```

### Caddy Not Binding to ZeroTier IP

**Check if ZT_IP is set:**
```bash
docker exec mysite-gateway env | grep ZT_IP
```

**If empty, ZeroTier might not be ready:**
```bash
# Restart gateway
docker-compose restart gateway

# Watch logs
docker logs -f mysite-gateway
```

### Gateway IP Changed

**After reauthorization or network changes:**

```bash
# Get new IP
docker exec mysite-gateway zerotier-cli listnetworks

# Update client DNS (depending on option):
# Option 1: Update /etc/hosts
# Option 2: CoreDNS auto-updates (wait 60s)
# Option 3: Re-run zt2hosts.sh
```

---

## Security Considerations

### ZeroTier-Only Access

By default, the gateway only binds to the ZeroTier interface:
- Not accessible from public internet
- Not accessible from host machine's other interfaces
- Only accessible via ZeroTier network

### Enabling SSL

Only enable SSL if you have a public domain and want public access:
```bash
SSL_ENABLED=true
DOMAIN=public.example.com
EMAIL=admin@example.com
```

**This will:**
- Request Let's Encrypt certificate
- Bind to all interfaces (0.0.0.0:443)
- Make service publicly accessible

### Best Practices

1. **Keep SSL disabled** for ZeroTier-only access
2. **Use strong passwords** for exposed services
3. **Limit ZeroTier network members** to trusted devices
4. **Regularly update** Docker images
5. **Monitor access logs** via Caddy logs

---

## Migration from SWAG/Other Proxies

### From SWAG

Replace SWAG container with this gateway:

**Before (SWAG):**
```yaml
swag:
  image: linuxserver/swag
  ports:
    - 443:443
    - 80:80
  environment:
    - URL=example.com
    - SUBDOMAINS=wildcard
```

**After (Gateway):**
```yaml
gateway:
  image: ghcr.io/zachhandley/zerotier-docker-gateway:latest
  cap_add:
    - NET_ADMIN
    - SYS_ADMIN
  devices:
    - /dev/net/tun
  environment:
    - SITE_NAME=mysite
    - NETWORK_ID=abc123def456
    - ENDPOINTS=wordpress:80
```

**Benefits:**
- 84% smaller (62MB vs 400MB)
- No public SSL complexity
- Automatic ZeroTier integration
- DNS-based service discovery

### From Nginx Proxy Manager

Keep NPM on control server for public routing, add gateways to workload servers:

**Server A (Control):**
- Keep Nginx Proxy Manager
- Add CoreDNS container
- Route: `public.example.com` → `service.zmesh`

**Server B+ (Workload):**
- Replace NPM with Gateway
- Services accessible via `.zmesh`

---

## Example Deployments

### WordPress Blog

```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: myblog-wp
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: secret123
    volumes:
      - wp_data:/var/www/html
    networks:
      - internal

  db:
    image: mariadb:10.6
    container_name: myblog-db
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: secret123
      MYSQL_RANDOM_ROOT_PASSWORD: 'yes'
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - internal

  gateway:
    image: ghcr.io/zachhandley/zerotier-docker-gateway:latest
    container_name: myblog-gateway
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "80:80"
    environment:
      - SITE_NAME=myblog
      - NETWORK_ID=abc123def456
      - ENDPOINTS=wordpress:80
      - GATEWAY_MODE=inbound
    volumes:
      - zt_data:/var/lib/zerotier-one
      - caddy_data:/data/caddy
    networks:
      - internal

networks:
  internal:
    name: myblog_internal

volumes:
  wp_data:
  db_data:
  zt_data:
  caddy_data:
```

### Multi-Service Stack

```yaml
version: '3.8'

services:
  grafana:
    image: grafana/grafana:latest
    networks:
      - internal

  prometheus:
    image: prom/prometheus:latest
    networks:
      - internal

  alertmanager:
    image: prom/alertmanager:latest
    networks:
      - internal

  gateway:
    image: ghcr.io/zachhandley/zerotier-docker-gateway:latest
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "80:80"
    environment:
      - SITE_NAME=monitoring
      - NETWORK_ID=abc123def456
      - ENDPOINTS=grafana:3000,prometheus:9090,alertmanager:9093
      - DOMAINS=grafana.zmesh,prom.zmesh,alerts.zmesh
      - GATEWAY_MODE=inbound
    volumes:
      - zt_data:/var/lib/zerotier-one
      - caddy_data:/data/caddy
    networks:
      - internal

networks:
  internal:
    name: monitoring_internal

volumes:
  zt_data:
  caddy_data:
```

Access:
- `http://grafana.zmesh` → Grafana
- `http://prom.zmesh` → Prometheus
- `http://alerts.zmesh` → Alertmanager

---

## Performance Notes

### Network Overhead

- ZeroTier adds minimal latency (typically 1-5ms on same LAN)
- Caddy reverse proxy adds ~1ms
- Total overhead: ~2-6ms vs direct access

### Resource Usage

**Gateway Container:**
- CPU: ~0.5-1% idle, 5-10% under load
- RAM: ~50-100MB
- Disk: 62.7MB image size

**Suitable for:**
- Low-power devices (Raspberry Pi, NUC)
- VPS with limited resources
- High-density container hosts

---

## FAQ

### Q: Why not use ZeroTier's managed routes?

**A:** The gateway handles routing automatically. ZeroTier's auto-routing to member IPs means no manual route configuration is needed.

### Q: Can I use a different domain than .zmesh?

**A:** Yes, configure `DOMAINS` environment variable:
```bash
DOMAINS=myblog.local,api.local
```

### Q: Does this work with Docker Swarm/Kubernetes?

**A:** Currently designed for Docker Compose. Swarm/K8s support is planned.

### Q: Can I run multiple gateways on the same server?

**A:** Yes, each gets its own ZeroTier IP and can serve different services.

### Q: What happens if the gateway restarts?

**A:** ZeroTier IP is stable (tied to network membership). Services reconnect automatically.

### Q: Can I access services from the host machine?

**A:** By default, no (Caddy binds to ZT IP only). For host access, add to /etc/hosts or use CoreDNS.

### Q: Does this work with IPv6?

**A:** ZeroTier supports IPv6, but this gateway currently focuses on IPv4. IPv6 support coming soon.

---

## Contributing

Found a bug or have a feature request? Open an issue or PR:

**GitHub:** https://github.com/zachhandley/zerotier-caddy-gateway

---

## License

MIT License - See LICENSE file for details

---

## Credits

Created by Zach Handley
- GitHub: https://github.com/ZachHandley
- Website: https://zachhandley.com

Built on:
- [bfg100k/zerotier-gateway](https://hub.docker.com/r/bfg100k/zerotier-gateway)
- [Caddy Server](https://caddyserver.com/)
- [ZeroTier](https://www.zerotier.com/)
