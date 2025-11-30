# syntax=docker/dockerfile:1.7
# =============================================================================
# VNtyper Proxy - Hardened Nginx Reverse Proxy
# =============================================================================
# Security features:
# - Pinned base image with SHA digest (supply chain security)
# - Minimal attack surface (alpine-slim)
# - Optimized layer caching
# - OCI labels for traceability
# =============================================================================

# Pin base image with digest for supply chain security
# nginx:1.27.3-alpine-slim
FROM nginx:1.27.3-alpine-slim@sha256:5a56ae385906c5b43ccc99379bce883aa93dc0556d7f705ba501d819925e8fa1

# OCI Labels for image metadata and traceability
LABEL org.opencontainers.image.title="VNtyper Proxy" \
      org.opencontainers.image.description="Hardened Nginx reverse proxy for VNtyper Online" \
      org.opencontainers.image.vendor="VNtyper Project" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/berntpopp/vntyper-online-backend" \
      org.opencontainers.image.documentation="https://github.com/berntpopp/vntyper-online-backend"

# Install required packages in a single layer
# - gettext: for envsubst (config templating)
# - bash: for entrypoint script
# - curl: for health checks
# - inotify-tools: for certificate change monitoring
RUN apk add --no-cache \
        gettext \
        bash \
        curl \
        inotify-tools \
    && rm -rf /var/cache/apk/*

# Create custom nginx.conf that works with read-only filesystem
# - Use /tmp for pid file (tmpfs mounted at runtime)
# - Use /dev/stdout and /dev/stderr for logs (no disk writes)
RUN printf '%s\n' \
    'user nginx;' \
    'worker_processes auto;' \
    'error_log /dev/stderr notice;' \
    'pid /tmp/nginx.pid;' \
    '' \
    'events {' \
    '    worker_connections 1024;' \
    '}' \
    '' \
    'http {' \
    '    include /etc/nginx/mime.types;' \
    '    default_type application/octet-stream;' \
    '' \
    '    log_format main '\''$remote_addr - $remote_user [$time_local] "$request" '\''' \
    '                    '\''$status $body_bytes_sent "$http_referer" '\''' \
    '                    '\''"$http_user_agent" "$http_x_forwarded_for"'\'';' \
    '' \
    '    access_log /dev/stdout main;' \
    '' \
    '    sendfile on;' \
    '    keepalive_timeout 65;' \
    '' \
    '    # Temp paths for read-only filesystem (tmpfs mounted at runtime)' \
    '    client_body_temp_path /tmp/nginx/client_body;' \
    '    proxy_temp_path /tmp/nginx/proxy;' \
    '    fastcgi_temp_path /tmp/nginx/fastcgi;' \
    '    uwsgi_temp_path /tmp/nginx/uwsgi;' \
    '    scgi_temp_path /tmp/nginx/scgi;' \
    '' \
    '    include /etc/nginx/conf.d/*.conf;' \
    '}' \
    > /etc/nginx/nginx.conf

# Copy Nginx configuration templates
COPY nginx.conf.template.http /etc/nginx/conf.d/nginx.conf.template.http
COPY nginx.conf.template.ssl /etc/nginx/conf.d/nginx.conf.template.ssl
COPY nginx.conf.template.acme /etc/nginx/conf.d/nginx.conf.template.acme

# Copy entrypoint script with explicit permissions
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Create required directories for nginx operation
# These will be overlaid with tmpfs at runtime for read-only filesystem
RUN mkdir -p /tmp/nginx/client_body \
             /tmp/nginx/proxy \
             /tmp/nginx/fastcgi \
             /tmp/nginx/uwsgi \
             /tmp/nginx/scgi \
    && chown -R nginx:nginx /tmp/nginx

# Note: This container runs as root because:
# 1. entrypoint.sh needs to write to /etc/nginx/conf.d/default.conf
# 2. inotifywait needs to monitor certificate files
# 3. nginx -s reload needs to signal the master process
# Security is enforced via docker-compose security options instead

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Health check - verify nginx is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost/health || curl -sf http://localhost/ || exit 1

# Set entrypoint and default command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
