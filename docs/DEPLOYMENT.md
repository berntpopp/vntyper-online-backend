# VNtyper Online - Production Deployment

## Quick Start

```bash
# First deployment or after upgrading to non-root containers
sudo ./scripts/deploy.sh --fix-perms --no-cache

# Regular updates
sudo ./scripts/deploy.sh
```

## Prerequisites

- Docker and Docker Compose installed
- Git with submodule support
- `.env.production` file configured (see [Configuration](#configuration))
- Domain DNS pointing to your server
- Ports 80 and 443 open

## Directory Structure

```
/var/www/vntyper/vntyper-online-backend/   # Application root
/etc/ssl/certs/vntyper/                     # SSL certificates (Let's Encrypt)
/var/www/certbot/                           # ACME challenge files
```

## Deployment Script

The `scripts/deploy.sh` script handles the full deployment:

```bash
sudo ./scripts/deploy.sh [OPTIONS]

Options:
  --no-cache    Force rebuild without Docker cache
  --fix-perms   Fix host directory permissions (required once)
  --pull-only   Only pull code, don't restart services
  --help        Show help
```

## Manual Deployment

If you prefer manual steps:

```bash
cd /var/www/vntyper/vntyper-online-backend/

# 1. Pull latest code
git pull origin main
git submodule update --init --recursive

# 2. Stop services
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml down

# 3. Build (add --no-cache for clean build)
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml build

# 4. Start
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml up -d

# 5. Verify
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml ps
curl -s http://localhost:8000/api/health/
```

## Configuration

### Environment File (.env.production)

```bash
# Core
ENVIRONMENT=production
SERVER_NAME=yourdomain.org
SERVER_NAME_SUBDOMAIN=www.yourdomain.org

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<strong-password>

# Storage (host paths)
INPUT_VOLUME=/var/www/vntyper/data/input
OUTPUT_VOLUME=/var/www/vntyper/data/output

# SSL (Let's Encrypt)
CERTBOT_EMAIL=admin@yourdomain.org
CERTBOT_STAGING=0  # Set to 1 for testing

# Email notifications (optional)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=<username>
SMTP_PASSWORD=<password>
API_BASE_URL=https://yourdomain.org
```

### Host Directory Permissions

Containers run as non-root users for security. Set permissions once:

```bash
# Certbot directories (uid 1000)
sudo mkdir -p /etc/ssl/certs/vntyper /var/www/certbot
sudo chown -R 1000:1000 /etc/ssl/certs/vntyper /var/www/certbot

# Data directories
sudo mkdir -p /var/www/vntyper/data/{input,output}
sudo chmod 755 /var/www/vntyper/data/{input,output}
```

Or use the script:

```bash
sudo ./scripts/deploy.sh --fix-perms
```

## SSL Certificates

### Initial Setup

1. Start with `CERTBOT_STAGING=1` to test without rate limits
2. Deploy and verify ACME challenge works
3. Set `CERTBOT_STAGING=0` and redeploy for real certificate

### Certificate Renewal

Automatic. The certbot container checks every 12 hours and renews when < 30 days remain. The proxy auto-reloads on renewal.

### Manual Renewal

```bash
# Force renewal
docker exec vntyper_certbot certbot renew --force-renewal

# Check expiration
docker exec vntyper_certbot openssl x509 -enddate -noout \
    -in /etc/letsencrypt/live/yourdomain.org/fullchain.pem
```

## Monitoring

### Health Checks

```bash
# API health
curl -s https://yourdomain.org/api/health/

# Container status
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml ps
```

### Logs

```bash
# All services
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml logs -f

# Specific service
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml logs -f backend_api
```

### Service-Specific Commands

```bash
# Enter container shell
docker exec -it vntyper_backend_api bash

# Check Celery workers
docker exec vntyper_online_worker celery -A app.celery_app inspect active

# Redis CLI
docker exec -it vntyper_online_redis redis-cli -a <password>
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs vntyper_<service_name>

# Check permissions
ls -la /etc/ssl/certs/vntyper/
ls -la /var/www/certbot/
```

### SSL Certificate Issues

```bash
# Check certbot logs
docker logs vntyper_certbot

# Verify ACME challenge path
curl -I http://yourdomain.org/.well-known/acme-challenge/test
```

### Permission Denied Errors

```bash
# Re-run permission fix
sudo ./scripts/deploy.sh --fix-perms
```

### Full Reset

```bash
# Stop everything
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml down -v

# Remove images
sudo docker image prune -a

# Fresh deploy
sudo ./scripts/deploy.sh --fix-perms --no-cache
```

## Security Notes

All containers run as non-root users:

| Container | User | UID |
|-----------|------|-----|
| proxy | nginx | 101 |
| certbot | certbot | 1000 |
| redis | redis | 999 |
| backend_* | vntyper | 1000 |

Additional hardening:
- `no-new-privileges` prevents privilege escalation
- `cap_drop: ALL` removes all Linux capabilities
- `read_only` filesystem where possible
- Resource limits prevent DoS
