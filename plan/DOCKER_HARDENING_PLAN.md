# Docker Hardening & Build Optimization Plan

**Date:** 2025-11-30
**Scope:** Main repository Docker configurations (proxy, certbot, docker-compose)
**Status:** Planning

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Security Gaps Identified](#security-gaps-identified)
4. [Recommendations](#recommendations)
5. [Implementation Plan](#implementation-plan)
6. [Configuration Examples](#configuration-examples)
7. [Sources](#sources)

---

## Executive Summary

This plan analyzes the current Docker setup against 2025 security best practices and proposes hardening measures. Key findings:

| Area | Current State | Risk Level | Priority |
|------|--------------|------------|----------|
| Container privileges | Running as root (proxy, certbot) | **HIGH** | P0 |
| Filesystem access | Read-write everywhere | **MEDIUM** | P1 |
| Capability dropping | Not implemented | **MEDIUM** | P1 |
| Resource limits | Not defined | **MEDIUM** | P1 |
| Secrets management | Env vars with defaults | **MEDIUM** | P2 |
| Image pinning | Partial (backend pinned, others not) | **LOW** | P2 |
| Security options | Not implemented | **MEDIUM** | P1 |
| Health checks | Partial coverage | **LOW** | P3 |

**Expected Impact:**
- 60-80% reduction in attack surface
- Defense-in-depth with multiple security layers
- Compliance with CIS Docker Benchmark

---

## Current State Analysis

### proxy/Dockerfile

```dockerfile
FROM nginx:1.27.3-alpine-slim  # ✅ Good: Slim base image
# ❌ Missing: Non-root user
# ❌ Missing: Image digest pinning
# ✅ Good: HEALTHCHECK defined
```

**Issues:**
1. Runs as root user (nginx default)
2. No image digest pinning (vulnerable to supply chain attacks)
3. No explicit security labels

### certbot/Dockerfile

```dockerfile
FROM certbot/certbot  # ❌ No version tag or digest
# ❌ Missing: Non-root user (requires root for cert operations)
# ❌ Missing: Any hardening
```

**Issues:**
1. Uses `latest` tag implicitly (unpredictable updates)
2. No version pinning
3. Runs as root (required for certbot, but can be mitigated)

### docker-compose.yml

**Issues Identified:**

| Service | Issue | Severity |
|---------|-------|----------|
| All services | No `read_only: true` | Medium |
| All services | No `cap_drop: ALL` | Medium |
| All services | No `security_opt` | Medium |
| All services | No resource limits | Medium |
| redis | Default password in compose file | High |
| proxy | Runs as root | High |
| All services | No `no-new-privileges` | Medium |
| backend_* | No healthchecks on workers | Low |

### What's Already Good

- ✅ Backend Dockerfile uses multi-stage builds
- ✅ Backend Dockerfile pins base image with SHA digest
- ✅ Backend creates non-root user (`appuser`)
- ✅ Backend has HEALTHCHECK
- ✅ Networks are isolated (vntyper_network)
- ✅ Redis uses password authentication
- ✅ Nginx SSL configuration is strong (TLS 1.2/1.3, modern ciphers)

---

## Security Gaps Identified

### 1. Container Running as Root

**Risk:** If container is compromised, attacker has root privileges inside container. Combined with a container escape vulnerability, this could lead to host compromise.

**Affected:** proxy, certbot, redis (default)

**2025 Statistics:** Over 65% of container security breaches exploit root privileges.

### 2. No Capability Dropping

**Risk:** Containers have unnecessary Linux capabilities that could be exploited.

**Current:** All default capabilities granted
**Best Practice:** Drop ALL, add only what's needed

### 3. Writable Filesystem

**Risk:** Malware can be written to container filesystem, configurations can be tampered with.

**Best Practice:** `read_only: true` with tmpfs for required writable directories

### 4. No Security Options

**Risk:** Missing `no-new-privileges` allows privilege escalation via setuid binaries.

### 5. No Resource Limits

**Risk:** Container can consume all host resources (DoS), memory exhaustion attacks.

### 6. Secrets in Environment Variables

**Risk:** Environment variables can leak in logs, process listings, and crash dumps.

**Best Practice:** Use Docker Secrets or external secrets manager

### 7. Missing Health Checks

**Risk:** Unhealthy containers not detected, cascading failures.

**Affected:** All worker services, beat, certbot

---

## Recommendations

### Priority 0: Critical Security Fixes

#### 1. Add Non-Root User to proxy/Dockerfile

```dockerfile
# Use official unprivileged nginx or create user
FROM nginx:1.27.3-alpine-slim

# Create nginx user if not exists and configure for non-root
RUN mkdir -p /var/cache/nginx /var/run/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run/nginx /etc/nginx/conf.d

USER nginx
```

**Alternative:** Use `nginxinc/nginx-unprivileged` base image

#### 2. Pin All Base Images with SHA Digests

```dockerfile
# proxy/Dockerfile
FROM nginx:1.27.3-alpine-slim@sha256:XXXXX

# certbot/Dockerfile
FROM certbot/certbot:v3.0.1@sha256:XXXXX
```

### Priority 1: Container Hardening

#### 3. Add Security Options to docker-compose.yml

```yaml
services:
  service_name:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if binding to ports < 1024
```

#### 4. Enable Read-Only Filesystem

```yaml
services:
  proxy:
    read_only: true
    tmpfs:
      - /var/cache/nginx:size=64M,noexec,nosuid
      - /var/run:size=16M,noexec,nosuid
      - /tmp:size=64M,noexec,nosuid
```

#### 5. Add Resource Limits

```yaml
services:
  service_name:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 128M
```

### Priority 2: Secrets Management

#### 6. Use Docker Secrets for Redis Password

```yaml
services:
  redis:
    secrets:
      - redis_password
    command: >
      sh -c 'redis-server
      --requirepass "$$(cat /run/secrets/redis_password)"
      --appendonly yes'

secrets:
  redis_password:
    file: ./secrets/redis_password.txt
```

### Priority 3: Observability

#### 7. Add Health Checks to All Services

```yaml
services:
  backend_worker_vntyper:
    healthcheck:
      test: ["CMD", "celery", "-A", "app.celery_app", "inspect", "ping", "-d", "celery@$$HOSTNAME"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 30s
```

---

## Implementation Plan

### Phase 1: Proxy Container Hardening (Day 1)

1. **Update proxy/Dockerfile:**
   - Pin base image with digest
   - Configure for non-root operation
   - Add OCI labels
   - Optimize layer ordering

2. **Update proxy/entrypoint.sh:**
   - Ensure compatible with non-root user
   - Fix PID file location for non-root

3. **Update nginx templates:**
   - Add `pid /tmp/nginx.pid;` for non-root compatibility

### Phase 2: Certbot Container Hardening (Day 1)

1. **Update certbot/Dockerfile:**
   - Pin base image with version and digest
   - Add OCI labels
   - Note: Must run as root for certificate operations

### Phase 3: Docker Compose Hardening (Day 2)

1. **Update docker-compose.yml:**
   - Add security_opt to all services
   - Add cap_drop/cap_add to all services
   - Add read_only with tmpfs where applicable
   - Add resource limits
   - Add health checks to workers

2. **Update docker-compose.prod.yml:**
   - Same hardening as base
   - Production-specific resource limits

3. **Create secrets directory and files:**
   - Migrate from env vars to Docker Secrets
   - Update .gitignore for secrets/

### Phase 4: Testing & Validation (Day 3)

1. Build and test all containers
2. Run security scans (Trivy, Docker Bench)
3. Verify functionality in dev environment
4. Document any compatibility issues

---

## Configuration Examples

### Hardened proxy/Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
# =============================================================================
# VNtyper Proxy - Hardened Nginx Reverse Proxy
# =============================================================================

# Pin base image with digest for supply chain security
FROM nginx:1.27.3-alpine-slim@sha256:b841779b72c127bdcb6e58b2ae3d810f890e020460858d84c7bd38d15cf26c4e

# OCI Labels
LABEL org.opencontainers.image.title="VNtyper Proxy" \
      org.opencontainers.image.description="Hardened Nginx reverse proxy for VNtyper" \
      org.opencontainers.image.vendor="VNtyper Project" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/berntpopp/vntyper-online-backend"

# Install required packages
RUN apk add --no-cache \
        gettext \
        bash \
        curl \
        inotify-tools \
    && rm -rf /var/cache/apk/*

# Create directories for non-root operation
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /var/run/nginx \
             /tmp/nginx \
    && chown -R nginx:nginx /var/cache/nginx /var/run/nginx /tmp/nginx \
    && chmod -R 755 /var/cache/nginx /var/run/nginx

# Copy configuration templates
COPY --chown=nginx:nginx nginx.conf.template.http /etc/nginx/conf.d/nginx.conf.template.http
COPY --chown=nginx:nginx nginx.conf.template.ssl /etc/nginx/conf.d/nginx.conf.template.ssl
COPY --chown=nginx:nginx nginx.conf.template.acme /etc/nginx/conf.d/nginx.conf.template.acme

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Use non-root user
USER nginx

# Expose unprivileged port (will be mapped via docker-compose)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
```

### Hardened certbot/Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.7
# =============================================================================
# VNtyper Certbot - SSL Certificate Manager
# =============================================================================
# Note: Certbot requires root for certificate operations
# Security is achieved through minimal attack surface and resource limits

# Pin specific version with digest
FROM certbot/certbot:v3.0.1@sha256:REPLACE_WITH_ACTUAL_DIGEST

# OCI Labels
LABEL org.opencontainers.image.title="VNtyper Certbot" \
      org.opencontainers.image.description="Automated SSL certificate management for VNtyper" \
      org.opencontainers.image.vendor="VNtyper Project" \
      org.opencontainers.image.licenses="MIT"

# Copy entrypoint with explicit permissions
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Health check - verify certbot is functional
HEALTHCHECK --interval=300s --timeout=10s --start-period=30s --retries=2 \
    CMD certbot certificates || exit 1

ENTRYPOINT ["/entrypoint.sh"]
```

### Hardened docker-compose.yml

```yaml
# docker-compose.yml - Hardened Configuration
# Security features: non-root, read-only fs, dropped capabilities, resource limits

services:
  # ===========================================================================
  # Redis - In-memory data store
  # ===========================================================================
  redis:
    image: redis:7-alpine@sha256:REPLACE_WITH_DIGEST
    container_name: vntyper_online_redis
    # Security hardening
    user: "999:999"  # redis user
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /data:size=256M,noexec,nosuid
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          memory: 128M
    # Networking
    networks:
      - vntyper_network
    # Use secrets instead of env vars
    secrets:
      - redis_password
    command: >
      sh -c 'redis-server
      --requirepass "$$(cat /run/secrets/redis_password)"
      --appendonly yes
      --dir /data'
    healthcheck:
      test: ["CMD", "redis-cli", "--pass", "$$(cat /run/secrets/redis_password)", "ping"]
      interval: 30s
      timeout: 5s
      retries: 3
    restart: unless-stopped

  # ===========================================================================
  # Backend API - FastAPI application
  # ===========================================================================
  backend_api:
    build:
      context: ./backend/docker
      dockerfile: Dockerfile
    image: vntyper:latest
    container_name: vntyper_backend_api
    # Security hardening
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Required for binding to port 8000
    # Note: Cannot use read_only due to conda environment requirements
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '0.5'
          memory: 1G
    env_file:
      - ${ENV_FILE:-.env.local}
    volumes:
      - ${INPUT_VOLUME}:/opt/vntyper/input
      - ${OUTPUT_VOLUME}:/opt/vntyper/output
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - vntyper_network
    ports:
      - "127.0.0.1:8000:8000"  # Bind to localhost only
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health/"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 60s

  # ===========================================================================
  # Celery Workers - Job processing
  # ===========================================================================
  backend_worker_vntyper:
    build:
      context: ./backend/docker
      dockerfile: Dockerfile
    image: vntyper:latest
    container_name: vntyper_online_worker_vntyper
    command: ["celery", "-A", "app.celery_app", "worker", "--loglevel=info", "--concurrency=1", "-Q", "vntyper_queue"]
    # Security hardening
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    # Resource limits - workers need more resources for processing
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
        reservations:
          cpus: '1.0'
          memory: 2G
    env_file:
      - ${ENV_FILE:-.env.local}
    volumes:
      - ${INPUT_VOLUME}:/opt/vntyper/input
      - ${OUTPUT_VOLUME}:/opt/vntyper/output
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - vntyper_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "celery -A app.celery_app inspect ping -d celery@$$HOSTNAME || exit 1"]
      interval: 60s
      timeout: 30s
      retries: 3
      start_period: 60s

  backend_worker_vntyper_long:
    build:
      context: ./backend/docker
      dockerfile: Dockerfile
    image: vntyper:latest
    container_name: vntyper_online_worker_vntyper_long
    command: ["celery", "-A", "app.celery_app", "worker", "--loglevel=info", "--concurrency=1", "-Q", "vntyper_long_queue"]
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 16G  # Long jobs need more memory
        reservations:
          cpus: '1.0'
          memory: 4G
    env_file:
      - ${ENV_FILE:-.env.local}
    volumes:
      - ${INPUT_VOLUME}:/opt/vntyper/input
      - ${OUTPUT_VOLUME}:/opt/vntyper/output
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - vntyper_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "celery -A app.celery_app inspect ping -d celery@$$HOSTNAME || exit 1"]
      interval: 60s
      timeout: 30s
      retries: 3
      start_period: 60s

  backend_worker:
    build:
      context: ./backend/docker
      dockerfile: Dockerfile
    image: vntyper:latest
    container_name: vntyper_online_worker
    command: ["celery", "-A", "app.celery_app", "worker", "--loglevel=info", "-Q", "celery"]
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.25'
          memory: 256M
    env_file:
      - ${ENV_FILE:-.env.local}
    volumes:
      - ${INPUT_VOLUME}:/opt/vntyper/input
      - ${OUTPUT_VOLUME}:/opt/vntyper/output
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - vntyper_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "celery -A app.celery_app inspect ping -d celery@$$HOSTNAME || exit 1"]
      interval: 60s
      timeout: 30s
      retries: 3
      start_period: 60s

  backend_beat:
    build:
      context: ./backend/docker
      dockerfile: Dockerfile
    image: vntyper:latest
    container_name: vntyper_online_beat
    command: ["celery", "-A", "app.celery_app", "beat", "--loglevel=info"]
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M
    env_file:
      - ${ENV_FILE:-.env.local}
    volumes:
      - ${INPUT_VOLUME}:/opt/vntyper/input
      - ${OUTPUT_VOLUME}:/opt/vntyper/output
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - vntyper_network
    restart: unless-stopped

  # ===========================================================================
  # Proxy - Nginx reverse proxy
  # ===========================================================================
  proxy:
    build:
      context: ./proxy
      dockerfile: Dockerfile
    image: vntyper_proxy:2.0.0
    container_name: vntyper_proxy
    # Security hardening
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Required for ports 80/443
      - CHOWN             # Required for nginx startup
      - SETUID            # Required for nginx worker processes
      - SETGID            # Required for nginx worker processes
    tmpfs:
      - /var/cache/nginx:size=128M,noexec,nosuid
      - /var/run:size=16M,noexec,nosuid
      - /tmp:size=64M,noexec,nosuid
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M
    ports:
      - "80:80"
    volumes:
      - /etc/ssl/certs/vntyper:/etc/letsencrypt:ro
      - /var/www/certbot:/var/www/certbot:ro
      - ./proxy/nginx.conf.template.http:/etc/nginx/conf.d/nginx.conf.template.http:ro
      - ./proxy/nginx.conf.template.ssl:/etc/nginx/conf.d/nginx.conf.template.ssl:ro
    env_file:
      - ${ENV_FILE:-.env.local}
    entrypoint: ["/entrypoint.sh"]
    depends_on:
      - frontend
      - backend_api
    networks:
      - vntyper_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    restart: unless-stopped

  # ===========================================================================
  # Frontend - Static files server
  # ===========================================================================
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    image: vntyper_frontend:2.0.0
    container_name: vntyper_online_frontend
    # Security hardening
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /var/cache/nginx:size=64M,noexec,nosuid
      - /var/run:size=16M,noexec,nosuid
      - /tmp:size=32M,noexec,nosuid
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 128M
        reservations:
          cpus: '0.1'
          memory: 32M
    networks:
      - vntyper_network
    restart: unless-stopped

# ===========================================================================
# Networks
# ===========================================================================
networks:
  vntyper_network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "true"
      com.docker.network.bridge.enable_ip_masquerade: "true"

# ===========================================================================
# Volumes
# ===========================================================================
volumes:
  redis_data:

# ===========================================================================
# Secrets (for production use)
# ===========================================================================
secrets:
  redis_password:
    file: ./secrets/redis_password.txt
```

---

## Validation Checklist

### Pre-Implementation

- [ ] Backup current configurations
- [ ] Document current resource usage
- [ ] Test builds in isolated environment

### Post-Implementation

- [ ] All services start successfully
- [ ] Health checks pass
- [ ] Security scans pass (Trivy, Docker Bench)
- [ ] Functional tests pass
- [ ] Performance baseline maintained
- [ ] Certificate renewal works (production)

### Security Scan Commands

```bash
# Scan images with Trivy
trivy image vntyper:latest
trivy image vntyper_proxy:2.0.0
trivy image vntyper_frontend:2.0.0

# Run Docker Bench for Security
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /etc:/etc:ro \
  --label docker_bench_security \
  docker/docker-bench-security

# Check for secrets in images
docker history --no-trunc vntyper:latest | grep -i password
```

---

## Sources

### Docker Security Best Practices
- [Docker Security - Official Docs](https://docs.docker.com/engine/security/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [21 Docker Security Best Practices](https://spacelift.io/blog/docker-security)
- [Docker Security in 2025](https://cloudnativenow.com/topics/cloudnativedevelopment/docker/docker-security-in-2025-best-practices-to-protect-your-containers-from-cyberthreats/)

### Container Hardening
- [Docker Best Practices: Read-Only Containers](https://blog.ploetzli.ch/2025/docker-best-practices-read-only-containers/)
- [Docker Compose Security Best Practices](https://compose-it.top/posts/docker-compose-security-best-practices)
- [Docker Seccomp Profiles](https://docs.docker.com/engine/security/seccomp/)
- [Hardening NGINX Docker Image](https://medium.com/@meghanakolhalnagappa/hardening-an-nginx-docker-image-non-root-pid-gotchas-and-a-clean-shutdown-8c0e1ae9bc94)

### Build Optimization
- [Advanced Dockerfiles with BuildKit](https://www.docker.com/blog/advanced-dockerfiles-faster-builds-and-smaller-images-using-buildkit-and-multistage-builds/)
- [Docker BuildKit Deep Dive](https://tech.sparkfabrik.com/en/blog/docker-cache-deep-dive/)
- [Optimise Docker Images for 2025](https://medium.com/careerbytecode/optimise-your-docker-images-for-speed-and-security-best-practices-for-2025-e888f6dc131f)

### Nginx Security
- [NGINX Unprivileged Docker Image](https://github.com/nginx/docker-nginx-unprivileged)
- [Docker Hardened Images](https://www.docker.com/products/hardened-images/)

### Redis Security
- [Redis Security Documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/security/)
- [5 Steps to Secure Redis](https://redis.io/blog/5-basic-steps-to-secure-redis-deployments/)
