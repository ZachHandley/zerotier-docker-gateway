# ZeroTier Controller with ZTNet + Auto-DNS

Self-hosted ZeroTier network controller with ZTNet web UI and automatic DNS discovery via CoreDNS.

## Docker Networks

This stack requires **two** Docker networks that must be created **before** deployment using a pre-deploy script:

### 1. `zmesh-internal` (172.31.255.0/24)
**Purpose:** Internal service communication and DNS resolution

**What's on it:**
- CoreDNS (static IP: 172.31.255.69)
- postgres, ztnet, dns-updater
- Any service that needs DNS resolution for `.zmesh` domains

**When to join:**
- Your service needs to resolve `.zmesh` domain names
- Your service needs to access internal stack services (postgres, ztnet)

**Example:** Nginx Proxy Manager needs this for DNS lookups

### 2. `zmesh-network` (br-zmesh bridge)
**Purpose:** ZeroTier routing - direct access to ZeroTier network IPs

**What's on it:**
- Bridge interface `br-zmesh` connected to ZeroTier routing
- Services that need to send/receive traffic to ZeroTier IPs

**When to join:**
- Your service needs to route traffic to ZeroTier member IPs
- Your service should be accessible from ZeroTier members

**Example:** Nginx Proxy Manager needs this to route to resolved IPs

### Creating Networks (Pre-Deploy)

Before starting the stack for the first time, you must create the required Docker networks using the built-in `create-networks` script:

```bash
# From the zerotier-controller directory
docker compose run --rm znetwork-creator
```

This creates:
- `zmesh-internal` (172.31.255.0/24) - Internal service communication & DNS
- `zmesh-network` (br-zmesh bridge) - ZeroTier routing

**Why is this required?**

The zerotier-controller uses `network_mode: host` to access the host's network interfaces for ZeroTier routing. Containers using `network_mode: host` cannot join Docker networks, which means:

1. Docker Compose **cannot** automatically create these networks on stack startup
2. The controller cannot join these networks directly
3. Networks must exist **before** the stack starts

The `create-networks` script solves this by:
- Creating both networks with proper configuration
- Ensuring `br-zmesh` bridge name is predictable for ZeroTier routing
- Enabling other containers in the stack to join these networks
- Being idempotent (safe to run multiple times)

**For Komodo users:** Add this as a pre-deploy command in your stack configuration:
```bash
docker compose run --rm znetwork-creator
```

**Important:** Run the `create-networks` script **before** deploying the stack or other stacks that depend on these networks. Networks only need to be created once and will persist across stack restarts.

### Typical Usage Pattern

Most services on Server A that proxy to ZeroTier services need **BOTH** networks:

```yaml
services:
  nginx-proxy-manager:
    networks:
      - zmesh-internal  # DNS: Resolve service.zmesh → 10.x.x.x
      - zmesh-network   # Routing: Send traffic to 10.x.x.x
```

## zmesh-network Auto-Routing

This custom ZeroTier controller image automatically creates and manages a Docker network called `zmesh-network` that provides seamless ZeroTier access to any container that joins it.

### Key Features

- **Automatic Network Creation**: Creates `zmesh-network` Docker bridge with predictable name `br-zmesh`
- **Zero Configuration**: No manual bridge name configuration needed
- **Automatic Routing**: Services joining `zmesh-network` get instant ZeroTier access
- **Universal Compatibility**: Works with any Docker Compose stack on the same host

### How It Works

1. **Custom Image**: Extends `zyclonite/zerotier:router` with Docker CLI and custom entrypoint
2. **Network Creation**: `entrypoint-zmesh.sh` creates `zmesh-network` with explicit bridge name `br-zmesh`
3. **Automatic Routing**: Adds `br-zmesh` to `ZEROTIER_ONE_LOCAL_PHYS` for ZeroTier routing
4. **Service Integration**: Any container joining `zmesh-network` routes through ZeroTier automatically

### Usage Example

Add `zmesh-network` to any Docker Compose service on the same host:

```yaml
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    networks:
      - public          # External connectivity
      - zmesh-network   # ZeroTier access
    # ... rest of config ...

networks:
  public:
    external: true
  zmesh-network:
    external: true      # Network created by zerotier-controller
```

Now `nginx-proxy-manager` can access all ZeroTier network members directly, and vice versa - all ZeroTier members can reach services on this container.

### Building the Image

The custom image is built automatically when using `docker compose up`:

```bash
docker compose build zerotier-controller
```

This creates the local image `zerotier-router-zmesh:latest` with all the necessary routing configuration.

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and set:
- `NEXTAUTH_URL` - Your public URL (e.g., `https://ztnet.example.com`)
- `NEXTAUTH_SECRET` - Generate with `openssl rand -base64 32`
- `POSTGRES_PASSWORD` - Set a secure password

**Leave `ZT_SECRET` empty for now** - we'll get it after first launch.

### 2. Create Docker Networks (One-Time Setup)

Before deploying the stack, create the required Docker networks:

```bash
docker compose run --rm znetwork-creator
```

This creates `zmesh-internal` and `zmesh-network` with proper configuration. **This step is required** because the controller uses `network_mode: host` and cannot join Docker networks, so Docker Compose cannot auto-create them.

### 3. Launch the Stack

```bash
docker compose up -d
```

**What happens on first boot:**
- All containers start and join their respective networks (already created in step 2)
- The zerotier-controller configures ZeroTier routing via `br-zmesh` bridge
- Everything is ready to use

**Important:** The `create-networks` step must be run **first** before this stack or other stacks that need to join `zmesh-internal` or `zmesh-network`. Networks only need to be created once.

### 4. Get ZeroTier Secret

After containers start, get the auth token:

```bash
docker exec zerotier-controller cat /var/lib/zerotier-one/authtoken.secret
```

Add this value to `ZT_SECRET` in `.env`, then restart:

```bash
docker compose down && docker compose up -d
```

### 5. Access ZTNet Web UI

Navigate to your `NEXTAUTH_URL` and create your admin account.

### 6. Create Your First Network

1. Log into ZTNet
2. Create a new network
3. Note the Network ID (16-character hex string)
4. Configure network settings:
   - Enable "Private" if you want to manually authorize members
   - Configure IP assignment range (e.g., `10.121.15.0/24`)
   - Add DNS entries for service discovery

### 7. Get Your API Key & Configure CoreDNS

1. Go to User Settings in ZTNet
2. Generate an API key
3. Add to `.env`:
   ```bash
   ZEROTIER_API_KEY=your_api_key_here
   NETWORK_ID=your_network_id_here
   ```
4. Restart to enable automatic DNS discovery:
   ```bash
   docker compose down && docker compose up -d
   ```

CoreDNS will now automatically discover all authorized network members and serve DNS at `*.zmesh`.

### 8. Configure DNS for Other Services on Server A

CoreDNS runs on **both** the `zmesh-internal` network (with static IP `172.31.255.69`) and the `public` network. This allows any service on Server A to use CoreDNS for `.zmesh` service discovery.

To configure other services on Server A to use CoreDNS, add DNS configuration to their `docker-compose.yml`:

```yaml
services:
  your-proxy-service:
    # ... other config ...
    networks:
      - zmesh-internal
    dns:
      - 172.31.255.69   # CoreDNS for .zmesh resolution
      - 127.0.0.11      # Docker's internal DNS (for container name resolution)
      - 1.1.1.1         # Fallback for public internet DNS queries
```

**How it works:**
- Any service connected to `zmesh-internal` can reach CoreDNS at `172.31.255.69`
- CoreDNS handles all `.zmesh` domain queries (ZeroTier member names)
- Docker's DNS (`127.0.0.11`) handles container name resolution
- Fallback DNS (`1.1.1.1` or `8.8.8.8`) handles public internet domains

This enables **DNS-based service discovery** - services on Server A can access ZeroTier network members by name without knowing their IPs.

### 9. Configure Remote Clients

Point remote clients (laptops, desktops) to use this server's ZeroTier IP as DNS:

```bash
# On Linux clients
sudo resolvectl dns zt0 <server-zerotier-ip>
sudo resolvectl domain zt0 '~zmesh'
```

Now clients can access gateways by name: `curl http://mysite.zmesh`

## Setup Flow Summary

```
1. Configure .env → 2. Create networks (docker compose run --rm znetwork-creator)
     ↓
3. Launch stack (docker compose up -d)
     ↓
4. Get ZT_SECRET → 5. Restart with secret
     ↓
6. Access web UI → 7. Create account → 8. Create network
     ↓
9. Get API key → 10. Add to .env + restart → 11. CoreDNS auto-discovers members
     ↓
12. Configure Server A services (add DNS: 172.31.255.69 to docker-compose)
     ↓
13. Configure remote clients to use DNS
```

**Note:** Networks `zmesh-internal` and `zmesh-network` must be created **before** launching the stack using the `create-networks` script. This is required because the controller uses `network_mode: host` and Docker Compose cannot auto-create networks for host-mode containers.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TZ` | No | Timezone (default: America/Los_Angeles) |
| `POSTGRES_USER` | Yes | Database user |
| `POSTGRES_PASSWORD` | Yes | Database password |
| `POSTGRES_DB` | Yes | Database name |
| `ZT_SECRET` | Yes | ZeroTier auth token (from controller container) |
| `NEXTAUTH_URL` | Yes | Public URL for ZTNet web UI |
| `NEXTAUTH_SECRET` | Yes | Random secret for NextAuth (use `openssl rand -base64 32`) |
| `ZEROTIER_API_KEY` | Yes* | API key from ZTNet user account (for CoreDNS auto-discovery) |
| `NETWORK_ID` | Yes* | ZeroTier network ID (for CoreDNS to monitor) |

\* Required for CoreDNS auto-discovery. Without these, DNS must be configured manually.

## How It Works

This stack provides automatic DNS service discovery for your ZeroTier network:

1. **CoreDNS** queries the ZTNet API every 60 seconds
2. Discovers all **authorized** network members with assigned IPs
3. Automatically generates DNS records: `<member-name>.zmesh → <member-zt-ip>`
4. Clients use this server's ZeroTier IP as their DNS server
5. Access services by name: `http://mysite.zmesh` instead of `http://10.121.15.217`

**No manual route management needed** - ZeroTier automatically routes traffic between members!

## Troubleshooting

**ztNET can't connect to controller:**
- Verify `ZT_SECRET` matches the authtoken.secret from the container
- Check that `ZT_ADDR=http://zerotier-controller:9993` is correct
- Ensure both containers are on the same `zmesh-internal` network

**Can't access web UI:**
- Check that port 3000 is exposed
- Verify `NEXTAUTH_URL` is set correctly
- If using a reverse proxy, ensure it's configured to proxy to port 3000

**Database connection errors:**
- Verify postgres container is running
- Check `POSTGRES_*` variables match in both postgres and ztnet services

**CoreDNS not discovering members:**
- Check `ZEROTIER_API_KEY` and `NETWORK_ID` are set in `.env`
- Verify API key is valid in ZTNet web UI
- Check CoreDNS logs: `docker logs zerotier-coredns`
- Ensure members are **authorized** in the network
- Verify members have IP assignments

**DNS queries not working:**
- Test DNS directly: `dig @<server-zt-ip> -p 5353 mysite.zmesh`
- Check client DNS configuration: `resolvectl status`
- Verify CoreDNS is running: `docker ps | grep coredns`
- Check zone file: `docker exec zerotier-coredns cat /data/zmesh.db`
