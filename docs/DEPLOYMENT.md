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

1. Linux, macOS, or Windows with WSL2
2. Docker and Docker Compose installed (`deploy.sh` calls the standalone `docker-compose`), and Git
3. The repository cloned with submodules: `git clone --recurse-submodules https://github.com/vntyper-org/vntyper-online-backend.git`
   (or `git submodule update --init --recursive` in an existing clone)
4. `.env.production` configured (copy from `.env.example`; never commit it, it holds secrets)
5. DNS A records for both the domain and its `www.` subdomain pointing to the server's public IP
6. Ports 80/443 open and not blocked by a firewall

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

`.env.example` documents every variable, including `PSEUDONYM_SECRET`, the PostgreSQL
settings and the feature flags. Notes on the ones that matter most:

- `CERTBOT_EMAIL` must be a valid address; Let's Encrypt sends expiry notices to it.
  `CERTBOT_STAGING=1` uses the Let's Encrypt staging servers for testing; set `0` in production.
- `MAX_RESULT_AGE_DAYS` is how long a completed job's result archive stays retrievable.
  `/download/{job_id}/` is an unauthenticated capability URL, so this value is the exposure
  window for a completed job. Keep it as short as collection allows: `vntyper online` polls
  for at most 4 hours and the completion email states no deadline, so the binding case is a
  person reading that email later. The default of 3 days covers submit-Friday,
  download-Monday. The env file overrides the image default, so its value governs.

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

# Build and start without deploy.sh
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml build
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml up -d

# List containers (expect backend_api, the workers, beat, frontend, proxy, certbot, redis, postgres)
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml ps

# Check status
curl -s https://yourdomain.org/api/health/
```

The `make prod-up`, `prod-down`, `prod-build`, `prod-logs` and `prod-status` targets wrap
the same commands with `docker compose`.

After a deploy, open `https://yourdomain.org` and confirm the certificate is valid and the
connection is secure.

## Backend Image Pinning

`docker-compose.yml` defaults `VNTYPER_IMAGE` to a digest-pinned release
(`ghcr.io/vntyper-org/vntyper:2.0.51@sha256:7f8b75af99f5e99283bfcf9828ba5874dc1e0d23dff7656346910f8c8bdf14ff...`). A digest reference
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

The proxy terminates TLS for the domain and redirects `www.` to it. The `certbot` container
obtains one certificate for both names and keeps it current in a loop (no cron); the proxy
watches the certificate files and reloads Nginx when they change. The security headers
(HSTS, CSP and others) are set in `proxy/nginx.conf.template.ssl`. Follow issuance with:

```bash
sudo docker-compose --env-file .env.production \
    -f docker-compose.yml -f docker-compose.prod.yml logs -f certbot
```

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
