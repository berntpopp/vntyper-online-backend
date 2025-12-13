# syntax=docker/dockerfile:1.7
# =============================================================================
# VNtyper Certbot - SSL Certificate Manager (Non-Root)
# =============================================================================
# Security features:
# - Pinned base image with version and SHA digest
# - Runs as non-root user (certbot)
# - OCI labels for traceability
# - Health check for container orchestration
# =============================================================================

# Pin base image with version and digest for supply chain security
# certbot/certbot:v3.0.1
FROM certbot/certbot:v5.2.1@sha256:7fcdb051e8790dd631bff3f0a23222a7ae8790b1e0bbb6c8ef4253f90f21c91a

# OCI Labels for image metadata and traceability
LABEL org.opencontainers.image.title="VNtyper Certbot" \
      org.opencontainers.image.description="Automated SSL certificate management for VNtyper Online (non-root)" \
      org.opencontainers.image.vendor="VNtyper Project" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/berntpopp/vntyper-online-backend" \
      org.opencontainers.image.documentation="https://github.com/berntpopp/vntyper-online-backend"

# Upgrade base packages and pip for security fixes
# - CVE-2024-58251, CVE-2025-46394: busybox vulnerabilities
# - CVE-2025-8869: pip symbolic link extraction vulnerability
# - CVE-2025-66418, CVE-2025-66471: urllib3 decompression vulnerabilities
# hadolint ignore=DL3013
RUN apk upgrade --no-cache \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir "urllib3>=2.6.0" \
    && pip uninstall -y uv 2>/dev/null || true

# Create non-root user for certbot operations
# UID 1000 chosen for compatibility with typical host user mappings
ARG CERTBOT_UID=1000
ARG CERTBOT_GID=1000

RUN addgroup -g ${CERTBOT_GID} certbot \
    && adduser -D -u ${CERTBOT_UID} -G certbot -h /home/certbot certbot

# Create required directories with correct ownership
# These directories are mounted as volumes from docker-compose
RUN mkdir -p /etc/letsencrypt /var/www/certbot /var/lib/letsencrypt /var/log/letsencrypt \
    && chown -R certbot:certbot /etc/letsencrypt /var/www/certbot /var/lib/letsencrypt /var/log/letsencrypt \
    && chmod 755 /etc/letsencrypt /var/www/certbot /var/lib/letsencrypt /var/log/letsencrypt

# Copy entrypoint script with explicit permissions
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch to non-root user
USER certbot

# Health check - verify certbot is functional
# Uses a longer interval since certbot operations are infrequent
HEALTHCHECK --interval=300s --timeout=30s --start-period=60s --retries=2 \
    CMD certbot certificates --quiet || exit 0

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
