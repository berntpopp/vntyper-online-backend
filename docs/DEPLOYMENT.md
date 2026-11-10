# Production Deployment

## Quick Start

```bash
cd /var/www/vntyper/vntyper-online-backend

# First time or after upgrade to non-root containers
sudo ./scripts/deploy.sh --fix-perms --no-cache

# Regular updates (pulls code, rebuilds, restarts)
sudo ./scripts/deploy.sh
```

The script handles: `git pull` → `submodule update` → `docker-compose down` → `build` → `up`

## Prerequisites

1. Docker & Docker Compose installed
2. `.env.production` configured (copy from `.env.example`)
3. Domain DNS pointing to server
4. Ports 80/443 open

## Environment File

Create `.env.production`:

```bash
ENVIRONMENT=production
SERVER_NAME=yourdomain.org
REDIS_PASSWORD=<strong-password>
INPUT_VOLUME=/var/www/vntyper/data/input
OUTPUT_VOLUME=/var/www/vntyper/data/output
CERTBOT_EMAIL=admin@yourdomain.org
CERTBOT_STAGING=0
```

## Script Options

```bash
sudo ./scripts/deploy.sh [OPTIONS]

--fix-perms   Fix host directory permissions (run once)
--no-cache    Force clean rebuild
--stop        Stop all services
```

## Manual Commands

```bash
cd /var/www/vntyper/vntyper-online-backend

# View logs
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml logs -f [service]

# Restart service
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml restart [service]

# Check status
curl -s https://yourdomain.org/api/health/
```

## Backend Image Pinning

`docker-compose.yml` defaults `VNTYPER_IMAGE` to a digest-pinned release
(`ghcr.io/hassansaei/vntyper:2.0.47@sha256:eea3dd94...`). A digest reference
cannot be used as a build tag, so `deploy.sh`'s build step no longer replaces
the running image: `up` pulls exactly the pinned digest. To roll forward, set
`VNTYPER_IMAGE` in `.env.production` (or bump the default) to a new
`tag@sha256:digest` (`docker buildx imagetools inspect <tag>` prints the digest).
`docker-compose.dev.yml` uses a local `vntyper-online:dev` tag so dev still runs
the local build.

## Redis Persistence

Redis stores its append-only file in the named volume `redis_data` (previously
a tmpfs), so the cumulative usage counter survives `docker-compose down` and
redeploys. The eviction policy is `volatile-lru`: only keys with a TTL (job IDs,
Celery results, per-job usage and cohort records) can be evicted; keys without a TTL (cumulative usage
counters, Celery queues) are never dropped, and at the 256 MB limit Redis rejects writes
with OOM instead. Do not run `docker-compose down -v` (or `docker volume rm`) in
production; that deletes the counter.

## SSL Certificates

- **Auto-renewal**: Certbot checks every 12h, renews at <30 days
- **Force renewal**: `docker exec vntyper_certbot certbot renew --force-renewal`
- **Check expiry**: `docker exec vntyper_certbot certbot certificates`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Permission denied | `sudo ./scripts/deploy.sh --fix-perms` |
| Container crash | `docker logs vntyper_<service>` |
| SSL not working | Check `docker logs vntyper_certbot` |
| Stale images | `sudo ./scripts/deploy.sh --no-cache` |
