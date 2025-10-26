#!/bin/bash
set -euo pipefail

# WordPress Docker Entrypoint Script
# Based on official WordPress image with enhancements

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Check if WordPress is already installed
if [ ! -e /var/www/html/index.php ] && [ ! -e /var/www/html/wp-includes/version.php ]; then
    log "WordPress not found in /var/www/html - copying from /usr/src/wordpress..."

    # Copy WordPress core files
    cp -a /usr/src/wordpress/. /var/www/html/

    log "WordPress core files copied successfully"
fi

# Generate wp-config.php if it doesn't exist and we have database credentials
if [ ! -e /var/www/html/wp-config.php ] && [ -n "${WORDPRESS_DB_HOST:-}" ]; then
    log "Generating wp-config.php..."

    # Database configuration
    DB_HOST="${WORDPRESS_DB_HOST:-db}"
    DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
    DB_USER="${WORDPRESS_DB_USER:-wordpress}"
    DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-}"
    DB_CHARSET="${WORDPRESS_DB_CHARSET:-utf8mb4}"
    DB_COLLATE="${WORDPRESS_DB_COLLATE:-}"
    TABLE_PREFIX="${WORDPRESS_TABLE_PREFIX:-wp_}"

    # Wait for database to be ready
    log "Waiting for database to be ready..."
    until mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --silent; do
        log "Waiting for database connection..."
        sleep 2
    done
    log "Database is ready!"

    # Download wp-config-sample.php if it doesn't exist
    if [ ! -e /var/www/html/wp-config-sample.php ]; then
        log "Downloading wp-config-sample.php..."
        curl -o /var/www/html/wp-config-sample.php https://raw.githubusercontent.com/WordPress/WordPress/master/wp-config-sample.php
    fi

    # Generate wp-config.php from sample
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    # Replace database configuration
    sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/wp-config.php
    sed -i "s/username_here/$DB_USER/g" /var/www/html/wp-config.php
    sed -i "s/password_here/$DB_PASSWORD/g" /var/www/html/wp-config.php
    sed -i "s/localhost/$DB_HOST/g" /var/www/html/wp-config.php
    sed -i "s/utf8/$DB_CHARSET/g" /var/www/html/wp-config.php
    sed -i "s/'wp_'/'$TABLE_PREFIX'/g" /var/www/html/wp-config.php

    # Generate and insert security keys
    log "Generating WordPress security keys..."
    KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    # Use environment variables for keys if provided, otherwise use generated ones
    if [ -n "${WORDPRESS_AUTH_KEY:-}" ]; then
        sed -i "/AUTH_KEY/c\define('AUTH_KEY',         '${WORDPRESS_AUTH_KEY}');" /var/www/html/wp-config.php
    else
        sed -i "/AUTH_KEY/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_SECURE_AUTH_KEY:-}" ]; then
        sed -i "/SECURE_AUTH_KEY/c\define('SECURE_AUTH_KEY',  '${WORDPRESS_SECURE_AUTH_KEY}');" /var/www/html/wp-config.php
    else
        sed -i "/SECURE_AUTH_KEY/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_LOGGED_IN_KEY:-}" ]; then
        sed -i "/LOGGED_IN_KEY/c\define('LOGGED_IN_KEY',    '${WORDPRESS_LOGGED_IN_KEY}');" /var/www/html/wp-config.php
    else
        sed -i "/LOGGED_IN_KEY/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_NONCE_KEY:-}" ]; then
        sed -i "/NONCE_KEY/c\define('NONCE_KEY',        '${WORDPRESS_NONCE_KEY}');" /var/www/html/wp-config.php
    else
        sed -i "/NONCE_KEY/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_AUTH_SALT:-}" ]; then
        sed -i "/AUTH_SALT/c\define('AUTH_SALT',        '${WORDPRESS_AUTH_SALT}');" /var/www/html/wp-config.php
    else
        sed -i "/AUTH_SALT/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_SECURE_AUTH_SALT:-}" ]; then
        sed -i "/SECURE_AUTH_SALT/c\define('SECURE_AUTH_SALT', '${WORDPRESS_SECURE_AUTH_SALT}');" /var/www/html/wp-config.php
    else
        sed -i "/SECURE_AUTH_SALT/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_LOGGED_IN_SALT:-}" ]; then
        sed -i "/LOGGED_IN_SALT/c\define('LOGGED_IN_SALT',   '${WORDPRESS_LOGGED_IN_SALT}');" /var/www/html/wp-config.php
    else
        sed -i "/LOGGED_IN_SALT/d" /var/www/html/wp-config.php
    fi

    if [ -n "${WORDPRESS_NONCE_SALT:-}" ]; then
        sed -i "/NONCE_SALT/c\define('NONCE_SALT',       '${WORDPRESS_NONCE_SALT}');" /var/www/html/wp-config.php
    else
        sed -i "/NONCE_SALT/d" /var/www/html/wp-config.php
    fi

    # Insert generated keys if environment variables weren't provided
    sed -i "/put your unique phrase here/r"<(echo "$KEYS") /var/www/html/wp-config.php
    sed -i "/put your unique phrase here/d" /var/www/html/wp-config.php

    # Add extra configuration if provided
    if [ -n "${WORDPRESS_CONFIG_EXTRA:-}" ]; then
        log "Adding extra WordPress configuration..."
        # Add before "/* That's all, stop editing! */"
        sed -i "/\/\* That's all/i ${WORDPRESS_CONFIG_EXTRA}" /var/www/html/wp-config.php
    fi

    # Add Redis object cache configuration if Redis is available
    if [ -n "${WORDPRESS_REDIS_HOST:-}" ]; then
        log "Configuring Redis object cache..."
        cat >> /var/www/html/wp-config.php <<EOF

// Redis Object Cache Configuration
define('WP_REDIS_HOST', '${WORDPRESS_REDIS_HOST}');
define('WP_REDIS_PORT', ${WORDPRESS_REDIS_PORT:-6379});
define('WP_REDIS_PASSWORD', '${WORDPRESS_REDIS_PASSWORD:-}');
define('WP_REDIS_DATABASE', ${WORDPRESS_REDIS_DATABASE:-0});
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);

EOF
    fi

    # Add debugging configuration
    if [ "${WORDPRESS_DEBUG:-0}" = "1" ]; then
        log "Enabling WordPress debugging..."
        cat >> /var/www/html/wp-config.php <<EOF

// Debug Configuration
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
define('SCRIPT_DEBUG', true);

EOF
    fi

    log "wp-config.php generated successfully"
fi

# Set proper permissions
log "Setting proper file permissions..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

log "WordPress initialization complete!"

# Execute the main command
exec "$@"
