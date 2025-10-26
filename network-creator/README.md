# ZMesh Network Creator

Utility container for creating Docker networks required by the zerotier-caddy-gateway stack.

## Usage

```bash
docker compose run --rm znetwork-creator
```

## What it does

Creates two Docker networks:
- `zmesh-internal` (172.31.255.0/24) - For DNS resolution and internal services
- `zmesh-network` (br-zmesh) - For ZeroTier routing

## Building

```bash
docker build -t zerotier-network-creator:latest .
```

## Standalone Usage

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock zerotier-network-creator:latest
```
