# ZeroTier Controller with ZTNet + Auto-DNS

Self-hosted ZeroTier network controller with ZTNet web UI and automatic DNS discovery via CoreDNS.

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

> **IMPORTANT:** Before deploying the controller, you must create the `public` Docker network:
> ```bash
> docker network create public
> ```
> This network is required for external connectivity and must exist before starting the stack.

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and set:
- `NEXTAUTH_URL` - Your public URL (e.g., `https://ztnet.example.com`)
- `NEXTAUTH_SECRET` - Generate with `openssl rand -base64 32`
- `POSTGRES_PASSWORD` - Set a secure password

**Leave `ZT_SECRET` empty for now** - we'll get it after first launch.

### 2. Launch the Stack

```bash
docker compose up -d
```

### 3. Get ZeroTier Secret

After containers start, get the auth token:

```bash
docker exec zerotier-controller cat /var/lib/zerotier-one/authtoken.secret
```

Add this value to `ZT_SECRET` in `.env`, then restart:

```bash
docker compose down && docker compose up -d
```

### 4. Access ZTNet Web UI

Navigate to your `NEXTAUTH_URL` and create your admin account.

### 5. Create Your First Network

1. Log into ZTNet
2. Create a new network
3. Note the Network ID (16-character hex string)
4. Configure network settings:
   - Enable "Private" if you want to manually authorize members
   - Configure IP assignment range (e.g., `10.121.15.0/24`)
   - Add DNS entries for service discovery

### 6. Get Your API Key & Configure CoreDNS

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

### 7. Configure DNS for Other Services on Server A

CoreDNS runs on **both** the `app-network` (with static IP `172.31.255.2`) and the `public` network. This allows any service on Server A to use CoreDNS for `.zmesh` service discovery.

To configure other services on Server A to use CoreDNS, add DNS configuration to their `docker-compose.yml`:

```yaml
services:
  your-proxy-service:
    # ... other config ...
    networks:
      - app-network
    dns:
      - 127.0.0.11      # Docker's internal DNS (for container name resolution)
      - 172.31.255.2    # CoreDNS for .zmesh resolution
      - 1.1.1.1         # Fallback for public internet DNS queries
```

**How it works:**
- Any service connected to `app-network` can reach CoreDNS at `172.31.255.2`
- Docker's DNS (`127.0.0.11`) handles container name resolution
- CoreDNS handles all `.zmesh` domain queries (ZeroTier member names)
- Fallback DNS (`1.1.1.1` or `8.8.8.8`) handles public internet domains

This enables **DNS-based service discovery** - services on Server A can access ZeroTier network members by name without knowing their IPs.

### 8. Configure Remote Clients

Point remote clients (laptops, desktops) to use this server's ZeroTier IP as DNS:

```bash
# On Linux clients
sudo resolvectl dns zt0 <server-zerotier-ip>
sudo resolvectl domain zt0 '~zmesh'
```

Now clients can access gateways by name: `curl http://mysite.zmesh`

## Setup Flow Summary

```
0. Create 'public' network (docker network create public)
     ↓
1. Launch stack → 2. Get ZT_SECRET → 3. Restart with secret
     ↓
4. Access web UI → 5. Create account → 6. Create network
     ↓
7. Get API key → 8. Add to .env + restart → 9. CoreDNS auto-discovers members
     ↓
10. Configure Server A services (add DNS: 172.31.255.2 to docker-compose)
     ↓
11. Configure remote clients to use DNS
```

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
- Ensure both containers are on the same `app-network`

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
