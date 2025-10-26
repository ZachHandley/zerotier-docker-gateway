# WordPress Production Image - Quick Start

This directory contains a production-optimized WordPress Docker image with all essential PHP extensions and security hardening.

## 3-Step Quick Start

### 1. Build the Image

```bash
cd /home/zach/github/zerotier-caddy-gateway/zwordpress
./build.sh --local
```

### 2. Validate the Image

```bash
./validate.sh zwordpress:latest
```

### 3. Deploy with Docker Compose

```bash
cd /home/zach/github/zerotier-caddy-gateway

# Edit docker-compose.wordpress.yaml and change:
# FROM: image: wordpress:latest
# TO:   image: zwordpress:latest

# Deploy
docker-compose -f docker-compose.wordpress.yaml up -d
```

## What's Included

### ✅ All Essential PHP Extensions
- **Database**: pdo_mysql, mysqli
- **Images**: gd (WebP/AVIF), imagick, exif
- **Caching**: opcache, redis, apcu
- **Utilities**: zip, intl, bcmath, soap, sockets

### ✅ Production Optimizations
- **Memory**: 256MB PHP limit
- **Uploads**: 128MB max file size
- **OPcache**: 256MB cache, 20K files
- **Execution**: 300s timeout

### ✅ Security Hardening
- PHP version exposure disabled
- Display errors off
- Dangerous functions disabled
- Session security enabled
- Apache security headers

## Files Overview

| File | Purpose |
|------|---------|
| `Dockerfile` | Main image definition with all extensions |
| `php.ini` | Production PHP configuration |
| `docker-entrypoint.sh` | Startup script for WordPress setup |
| `.dockerignore` | Build exclusions |
| `build.sh` | Build script with multi-platform support |
| `validate.sh` | Validation script to test image |
| `README.md` | Comprehensive documentation |
| `INTEGRATION.md` | Integration guide with ZeroTier Gateway |
| `QUICKSTART.md` | This file |

## Common Commands

### Build Commands

```bash
# Local build
./build.sh --local

# Build and push to Docker Hub
./build.sh --name yourusername/zwordpress --tag 1.0.0 --push

# Build and push to GHCR
./build.sh --registry ghcr.io/username --name zwordpress --tag latest --push
```

### Validation

```bash
# Validate the image
./validate.sh zwordpress:latest
```

### Container Management

```bash
# View logs
docker logs ${SITE_NAME}-wp

# Enter container
docker exec -it ${SITE_NAME}-wp bash

# Check PHP info
docker exec ${SITE_NAME}-wp php -i

# List PHP extensions
docker exec ${SITE_NAME}-wp php -m
```

### WordPress CLI

```bash
# Check WP-CLI version
docker exec ${SITE_NAME}-wp wp --version

# List plugins
docker exec ${SITE_NAME}-wp wp plugin list --allow-root

# Update WordPress
docker exec ${SITE_NAME}-wp wp core update --allow-root
```

## Optional: Add Redis Cache

1. Add Redis service to `docker-compose.wordpress.yaml`:

```yaml
redis:
  image: redis:7-alpine
  container_name: ${SITE_NAME}-redis
  networks:
    - internal
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
  volumes:
    - redis_data:/data
  restart: unless-stopped
```

2. Update WordPress environment:

```yaml
wordpress:
  environment:
    - WORDPRESS_REDIS_HOST=redis
    - WORDPRESS_REDIS_PORT=6379
    - WORDPRESS_CONFIG_EXTRA=define('DISALLOW_FILE_EDIT', true); define('WP_CACHE', true);
```

3. Install Redis Object Cache plugin:

```bash
docker exec ${SITE_NAME}-wp wp plugin install redis-cache --activate --allow-root
docker exec ${SITE_NAME}-wp wp redis enable --allow-root
```

## Troubleshooting

### Build fails
```bash
# Clear build cache and retry
docker builder prune -af
./build.sh --local
```

### Container won't start
```bash
# Check logs
docker logs ${SITE_NAME}-wp

# Check database connection
docker exec ${SITE_NAME}-wp mysqladmin ping -hdb -u${DB_USER} -p${DB_PASSWORD}
```

### Permission issues
```bash
# Fix permissions
docker exec ${SITE_NAME}-wp chown -R www-data:www-data /var/www/html
```

## Performance Tips

1. **Enable Redis object cache** (see above) - 3-5x performance improvement
2. **Use a CDN** for static assets
3. **Install image optimization plugin** (ShortPixel, Imagify)
4. **Keep WordPress and plugins updated**
5. **Monitor OPcache hit rate** (should be >95%)

## Security Checklist

- [x] PHP version exposure disabled (`expose_php=Off`)
- [x] Display errors disabled (`display_errors=Off`)
- [x] Dangerous functions disabled
- [x] File editing disabled (`DISALLOW_FILE_EDIT`)
- [x] Session security enabled
- [x] Apache security headers configured
- [ ] Install security plugin (Wordfence, Sucuri)
- [ ] Enable automatic updates
- [ ] Set up regular backups
- [ ] Use strong database passwords
- [ ] Limit login attempts

## Next Steps

1. ✅ Build the image
2. ✅ Validate the image
3. ✅ Update docker-compose.wordpress.yaml
4. ⬜ Deploy the stack
5. ⬜ Install Redis object cache
6. ⬜ Configure backups
7. ⬜ Set up monitoring

## Support

- See `README.md` for comprehensive documentation
- See `INTEGRATION.md` for ZeroTier Gateway integration
- Check [WordPress Codex](https://codex.wordpress.org/) for WordPress help
- Check [WP-CLI Docs](https://developer.wordpress.org/cli/commands/) for CLI commands

---

**Ready to deploy!** Follow the 3 steps above to get started.
