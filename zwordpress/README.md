# Production-Ready WordPress Docker Image

A production-optimized WordPress Docker image built on `wordpress:latest` with essential PHP extensions and security hardening that the official image lacks.

## Why This Exists

The official `wordpress:latest` image is missing critical production requirements:
- No `pdo_mysql` extension (required by many plugins and themes)
- Missing modern image format support (WebP, AVIF)
- Limited performance optimization extensions
- No Redis/caching support out of the box
- Minimal security hardening

This image addresses these gaps while maintaining full compatibility with WordPress core.

## What's Included

### PHP Extensions
This image includes PHP 8.2 with comprehensive extension support:

**Database & Core:**
- `pdo_mysql` - PDO MySQL driver (critical for many plugins)
- `mysqli` - MySQL improved extension
- `opcache` - Opcode cache for performance

**Image Processing:**
- `gd` - GD image library
- `imagick` - ImageMagick integration
- WebP and AVIF format support
- `exif` - Image metadata handling

**Performance & Caching:**
- `redis` - Redis client for object caching
- `apcu` - Alternative PHP Cache
- `opcache` - Optimized with production settings

**Security & Utilities:**
- `bcmath` - Arbitrary precision mathematics
- `intl` - Internationalization functions
- `zip` - Archive handling
- `soap` - SOAP protocol support
- `xmlrpc` - XML-RPC support

### Production Optimizations

**php.ini Configuration:**
```ini
# Memory & Execution
memory_limit = 2048M
max_execution_time = 600
max_input_time = 600

# File Uploads
upload_max_filesize = 1024M
post_max_size = 1024M

# OPcache (Production)
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.revalidate_freq = 0

# Security
expose_php = Off
display_errors = Off
log_errors = On
```

**Security Hardening:**
- Disabled PHP version exposure
- Error logging without display
- Optimized for production workloads
- Safe file upload limits

## Usage

### Docker Compose Example

```yaml
services:
  wordpress:
    image: your-registry/zwordpress:latest
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_REDIS_HOST', 'redis');
        define('WP_REDIS_PORT', 6379);
        define('WP_CACHE', true);
    volumes:
      - wordpress_data:/var/www/html
    depends_on:
      - db
      - redis
    networks:
      - wordpress_network

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    networks:
      - wordpress_network

  db:
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wordpress_network

volumes:
  wordpress_data:
  db_data:

networks:
  wordpress_network:
```

### Standalone Docker Run

```bash
docker run -d \
  --name wordpress \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=db:3306 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=secure_password \
  your-registry/zwordpress:latest
```

## Building the Image

### Local Build

```bash
# From the zwordpress directory
docker build -t zwordpress:latest .

# Test locally
docker run --rm -p 8080:80 zwordpress:latest
```

### Multi-Platform Build

```bash
# Create and use buildx builder
docker buildx create --use --name multiarch-builder

# Build for AMD64 and ARM64
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-registry/zwordpress:latest \
  --push .
```

### Publishing to Registries

**Docker Hub:**
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-username/zwordpress:latest \
  -t your-username/zwordpress:1.0.0 \
  --push .
```

**GitHub Container Registry:**
```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build and push
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/your-username/zwordpress:latest \
  -t ghcr.io/your-username/zwordpress:1.0.0 \
  --push .
```

## Recommended Plugins

This image is optimized for use with:
- **Redis Object Cache** - Leverage the built-in Redis support
- **Imagify or ShortPixel** - Image optimization with WebP/AVIF
- **WP Super Cache or W3 Total Cache** - Page caching
- **Wordfence or Sucuri** - Security scanning

## Configuration Tips

### Enable Redis Caching

Add to your `wp-config.php` or via `WORDPRESS_CONFIG_EXTRA`:
```php
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
```

### Performance Tuning

Default production limits are already set high for demanding workloads:
- Memory: 2GB
- Max execution time: 10 minutes
- File uploads: 1GB

For lower-resource environments, you can reduce these via environment variables:
```yaml
environment:
  PHP_MEMORY_LIMIT: 512M
  PHP_MAX_EXECUTION_TIME: 300
  PHP_UPLOAD_MAX_FILESIZE: 256M
```

### Security Headers (via Reverse Proxy)

When using with Caddy or nginx, add security headers:
```caddyfile
header {
    X-Frame-Options "SAMEORIGIN"
    X-Content-Type-Options "nosniff"
    Referrer-Policy "strict-origin-when-cross-origin"
    Permissions-Policy "geolocation=(self)"
}
```

## Maintenance

### Updating WordPress Core

```bash
# Pull latest image
docker pull your-registry/zwordpress:latest

# Recreate container
docker-compose up -d --force-recreate wordpress
```

### Backup Strategy

```bash
# Backup WordPress files
docker run --rm \
  -v wordpress_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/wordpress-$(date +%Y%m%d).tar.gz /data

# Backup database
docker exec db mysqldump -u wordpress -p wordpress > backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Check PHP Extensions

```bash
docker exec wordpress php -m
```

### View PHP Configuration

```bash
docker exec wordpress php -i | grep -E "(memory_limit|upload_max_filesize|opcache)"
```

### Check Logs

```bash
# WordPress/PHP logs
docker logs wordpress

# Error logs
docker exec wordpress tail -f /var/log/apache2/error.log
```

## License

This Dockerfile and configuration are provided as-is for production WordPress deployments. WordPress itself is licensed under GPL v2 or later.

## Contributing

Improvements and optimizations are welcome. Please ensure any changes maintain production stability and security standards.
