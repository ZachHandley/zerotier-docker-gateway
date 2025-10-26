#!/bin/bash
set -e

# WordPress Docker Image Validation Script
# Tests the built image for essential features and configurations

IMAGE_NAME="${1:-zwordpress:latest}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

ERRORS=0

echo "============================================"
echo "WordPress Docker Image Validation"
echo "============================================"
echo "Image: $IMAGE_NAME"
echo ""

# Check if image exists
log_test "Checking if image exists..."
if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_info "Image found"
else
    log_error "Image not found: $IMAGE_NAME"
    echo "Build the image first with: ./build.sh --local"
    exit 1
fi
echo ""

# Start temporary container for testing
log_test "Starting temporary container..."
CONTAINER_ID=$(docker run -d --rm "$IMAGE_NAME" tail -f /dev/null)
if [ -z "$CONTAINER_ID" ]; then
    log_error "Failed to start container"
    exit 1
fi
log_info "Container started: ${CONTAINER_ID:0:12}"
echo ""

# Cleanup function
cleanup() {
    if [ -n "$CONTAINER_ID" ]; then
        docker stop "$CONTAINER_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# Test PHP version
log_test "Checking PHP version..."
PHP_VERSION=$(docker exec "$CONTAINER_ID" php -v | head -1)
if [[ "$PHP_VERSION" == *"PHP 8.2"* ]]; then
    log_info "PHP 8.2 confirmed: $PHP_VERSION"
else
    log_error "Expected PHP 8.2, got: $PHP_VERSION"
    ((ERRORS++))
fi
echo ""

# Test required PHP extensions
log_test "Checking required PHP extensions..."
REQUIRED_EXTENSIONS=(
    "pdo_mysql"
    "mysqli"
    "gd"
    "imagick"
    "opcache"
    "redis"
    "apcu"
    "zip"
    "intl"
    "bcmath"
    "soap"
    "exif"
)

for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if docker exec "$CONTAINER_ID" php -m | grep -q "^$ext$"; then
        log_info "Extension found: $ext"
    else
        log_error "Extension missing: $ext"
        ((ERRORS++))
    fi
done
echo ""

# Test PHP configuration
log_test "Checking PHP configuration..."

check_ini_value() {
    local key=$1
    local expected=$2
    local actual=$(docker exec "$CONTAINER_ID" php -i | grep "^$key" | awk '{print $NF}')

    if [ "$actual" = "$expected" ]; then
        log_info "$key = $expected"
    else
        log_error "$key = $actual (expected: $expected)"
        ((ERRORS++))
    fi
}

check_ini_value "memory_limit" "256M"
check_ini_value "upload_max_filesize" "128M"
check_ini_value "post_max_size" "128M"
echo ""

# Test OPcache configuration
log_test "Checking OPcache configuration..."
OPCACHE_ENABLED=$(docker exec "$CONTAINER_ID" php -r "echo opcache_get_status()['opcache_enabled'] ?? 0;")
if [ "$OPCACHE_ENABLED" = "1" ]; then
    log_info "OPcache is enabled"

    # Check OPcache memory
    OPCACHE_MEMORY=$(docker exec "$CONTAINER_ID" php -i | grep "opcache.memory_consumption" | awk '{print $NF}')
    if [ "$OPCACHE_MEMORY" = "256" ]; then
        log_info "OPcache memory: 256MB"
    else
        log_error "OPcache memory: ${OPCACHE_MEMORY}MB (expected: 256)"
        ((ERRORS++))
    fi
else
    log_error "OPcache is not enabled"
    ((ERRORS++))
fi
echo ""

# Test Apache modules
log_test "Checking Apache modules..."
REQUIRED_APACHE_MODULES=(
    "rewrite"
    "expires"
    "headers"
    "deflate"
    "remoteip"
)

for mod in "${REQUIRED_APACHE_MODULES[@]}"; do
    if docker exec "$CONTAINER_ID" apache2ctl -M 2>/dev/null | grep -q "${mod}_module"; then
        log_info "Apache module loaded: $mod"
    else
        log_error "Apache module missing: $mod"
        ((ERRORS++))
    fi
done
echo ""

# Test WordPress CLI
log_test "Checking WordPress CLI..."
if docker exec "$CONTAINER_ID" wp --version >/dev/null 2>&1; then
    WP_CLI_VERSION=$(docker exec "$CONTAINER_ID" wp --version | awk '{print $2}')
    log_info "WP-CLI installed: $WP_CLI_VERSION"
else
    log_error "WP-CLI not found"
    ((ERRORS++))
fi
echo ""

# Test WordPress core files
log_test "Checking WordPress core files..."
if docker exec "$CONTAINER_ID" ls /usr/src/wordpress/wp-config-sample.php >/dev/null 2>&1; then
    log_info "WordPress core files present"
else
    log_error "WordPress core files missing"
    ((ERRORS++))
fi
echo ""

# Test security configurations
log_test "Checking security configurations..."

# Check expose_php
EXPOSE_PHP=$(docker exec "$CONTAINER_ID" php -i | grep "expose_php" | awk '{print $NF}')
if [ "$EXPOSE_PHP" = "Off" ] || [ "$EXPOSE_PHP" = "no" ]; then
    log_info "expose_php is Off"
else
    log_error "expose_php is On (should be Off)"
    ((ERRORS++))
fi

# Check display_errors
DISPLAY_ERRORS=$(docker exec "$CONTAINER_ID" php -i | grep "display_errors" | head -1 | awk '{print $NF}')
if [ "$DISPLAY_ERRORS" = "Off" ] || [ "$DISPLAY_ERRORS" = "no" ]; then
    log_info "display_errors is Off"
else
    log_error "display_errors is On (should be Off for production)"
    ((ERRORS++))
fi
echo ""

# Test file permissions
log_test "Checking file permissions..."
WWW_DATA_UID=$(docker exec "$CONTAINER_ID" id -u www-data)
if [ "$WWW_DATA_UID" = "33" ]; then
    log_info "www-data UID is correct: 33"
else
    log_error "www-data UID is $WWW_DATA_UID (expected: 33)"
    ((ERRORS++))
fi
echo ""

# Summary
echo "============================================"
echo "Validation Summary"
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "The image is ready for production use."
    echo ""
    echo "Next steps:"
    echo "  1. Push to registry: docker push $IMAGE_NAME"
    echo "  2. Update docker-compose.wordpress.yaml to use this image"
    echo "  3. Deploy: docker-compose up -d"
    exit 0
else
    echo -e "${RED}Failed with $ERRORS error(s)${NC}"
    echo ""
    echo "Please review the errors above and rebuild the image."
    exit 1
fi
