# syntax=docker/dockerfile:1.7
# =============================================================================
# VNtyper Proxy - Hardened Nginx Reverse Proxy (Non-Root)
# =============================================================================
# Security features:
# - Uses official nginx-unprivileged image (runs as non-root)
# - Pinned base image with SHA digest (supply chain security)
# - Minimal attack surface (alpine-slim)
# - OCI labels for traceability
# =============================================================================

# Pin base image with digest for supply chain security
# nginxinc/nginx-unprivileged:1.27.3-alpine-slim
FROM nginxinc/nginx-unprivileged:1.29.2-alpine-slim@sha256:046ac91ce56252873baf4aceb0ff3887c610d28461ca7d8e187cad737818e1e5

# OCI Labels for image metadata and traceability
LABEL org.opencontainers.image.title="VNtyper Proxy" \
      org.opencontainers.image.description="Hardened Nginx reverse proxy for VNtyper Online (non-root)" \
      org.opencontainers.image.vendor="VNtyper Project" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/berntpopp/vntyper-online-backend" \
      org.opencontainers.image.documentation="https://github.com/berntpopp/vntyper-online-backend"

# Switch to root temporarily to install packages and set permissions
USER root

# Install required packages and upgrade base packages for security fixes
# - gettext: for envsubst (config templating)
# - bash: for entrypoint script
# - curl: for health checks
# - inotify-tools: for certificate change monitoring
# - openssl: for OCSP stapling cache warm-up
# - apk upgrade: fixes CVE-2024-58251, CVE-2025-46394 in busybox
RUN apk upgrade --no-cache \
    && apk add --no-cache \
        gettext \
        bash \
        curl \
        inotify-tools \
        openssl \
    && rm -rf /var/cache/apk/*

# Copy Nginx configuration templates
# These are read-only templates used by entrypoint
COPY --chown=nginx:nginx nginx.conf.template.http /etc/nginx/templates/nginx.conf.template.http
COPY --chown=nginx:nginx nginx.conf.template.ssl /etc/nginx/templates/nginx.conf.template.ssl
COPY --chown=nginx:nginx nginx.conf.template.acme /etc/nginx/templates/nginx.conf.template.acme

# Create directories with correct ownership for non-root operation
# conf.d is where entrypoint writes the generated config
RUN mkdir -p /etc/nginx/conf.d \
    && chown -R nginx:nginx /etc/nginx/conf.d \
    && chmod 755 /etc/nginx/conf.d

# Copy entrypoint script with explicit permissions
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch back to non-root nginx user (UID 101 in nginx-unprivileged)
USER nginx

# Expose HTTP and HTTPS ports (unprivileged ports >= 1024 work without root)
# These are mapped to 80/443 in docker-compose
EXPOSE 8080 8443

# Health check - verify nginx is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:8080/health || exit 1

# Set entrypoint and default command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
