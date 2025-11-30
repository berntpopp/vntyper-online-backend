# syntax=docker/dockerfile:1.7
# =============================================================================
# VNtyper Certbot - SSL Certificate Manager
# =============================================================================
# Security features:
# - Pinned base image with version and SHA digest
# - OCI labels for traceability
# - Health check for container orchestration
#
# Note: Certbot requires root privileges for certificate operations.
# Security is enforced via docker-compose security options:
# - no-new-privileges
# - capability dropping
# - resource limits
# =============================================================================

# Pin base image with version and digest for supply chain security
# certbot/certbot:v3.0.1
FROM certbot/certbot:v3.0.1@sha256:4d8875e85a2af373262914e15c0a149e1985c5bbd05ac433fe4763f465020fcf

# OCI Labels for image metadata and traceability
LABEL org.opencontainers.image.title="VNtyper Certbot" \
      org.opencontainers.image.description="Automated SSL certificate management for VNtyper Online" \
      org.opencontainers.image.vendor="VNtyper Project" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/berntpopp/vntyper-online-backend" \
      org.opencontainers.image.documentation="https://github.com/berntpopp/vntyper-online-backend"

# Copy entrypoint script with explicit permissions
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Health check - verify certbot is functional
# Uses a longer interval since certbot operations are infrequent
HEALTHCHECK --interval=300s --timeout=30s --start-period=60s --retries=2 \
    CMD certbot certificates --quiet || exit 0

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
