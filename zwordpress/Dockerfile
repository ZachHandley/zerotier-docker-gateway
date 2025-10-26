# Production WordPress Docker Image
# Based on php:8.2-apache to match official wordpress:latest behavior
FROM php:8.2-apache

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Image processing
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libavif-dev \
    libmagickwand-dev \
    # Database
    default-mysql-client \
    # Compression
    libzip-dev \
    unzip \
    # Localization
    libicu-dev \
    # SOAP
    libxml2-dev \
    # Caching
    libmemcached-dev \
    # SSH/SFTP
    libssh2-1-dev \
    # Other utilities
    ghostscript \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif \
    && docker-php-ext-install -j$(nproc) \
    # Database
    pdo_mysql \
    mysqli \
    # Image processing
    gd \
    exif \
    # Performance
    opcache \
    # Utilities
    zip \
    intl \
    bcmath \
    soap \
    sockets \
    # Calendar
    calendar

# Install PECL extensions
RUN pecl install imagick redis apcu && \
    docker-php-ext-enable imagick redis apcu

# Enable Apache modules
RUN a2enmod rewrite expires headers deflate remoteip

# Download and install WordPress CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Download latest WordPress core
RUN set -ex; \
    curl -o wordpress.tar.gz -fSL "https://wordpress.org/latest.tar.gz"; \
    tar -xzf wordpress.tar.gz -C /usr/src/; \
    rm wordpress.tar.gz; \
    chown -R www-data:www-data /usr/src/wordpress

# Copy custom PHP configuration
COPY php.ini /usr/local/etc/php/conf.d/wordpress.ini

# Set up Apache security headers
RUN { \
    echo 'ServerTokens Prod'; \
    echo 'ServerSignature Off'; \
    echo 'TraceEnable Off'; \
    } >> /etc/apache2/conf-available/security.conf

# Configure Apache to respect X-Forwarded-For headers (for Caddy reverse proxy)
RUN { \
    echo 'RemoteIPHeader X-Forwarded-For'; \
    echo 'RemoteIPTrustedProxy 10.0.0.0/8'; \
    echo 'RemoteIPTrustedProxy 172.16.0.0/12'; \
    echo 'RemoteIPTrustedProxy 192.168.0.0/16'; \
    } > /etc/apache2/conf-available/remoteip.conf && \
    a2enconf remoteip

# Create entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

# Expose port 80
EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
