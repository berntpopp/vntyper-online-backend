# VNtyper Online backend

[![Lint workflow status](https://github.com/vntyper-org/vntyper-online-backend/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/vntyper-org/vntyper-online-backend/actions/workflows/lint.yml)
[![Security Scan workflow status](https://github.com/vntyper-org/vntyper-online-backend/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/vntyper-org/vntyper-online-backend/actions/workflows/security.yml)
[![Container Scan workflow status](https://github.com/vntyper-org/vntyper-online-backend/actions/workflows/container-scan.yml/badge.svg?branch=main)](https://github.com/vntyper-org/vntyper-online-backend/actions/workflows/container-scan.yml)
[![License: MIT](https://img.shields.io/github/license/vntyper-org/vntyper-online-backend)](LICENSE)
[![vntyper.org website status](https://img.shields.io/website?url=https%3A%2F%2Fvntyper.org&label=vntyper.org)](https://vntyper.org/)

This repository deploys the [vntyper.org](https://vntyper.org/) web service, which runs
[VNtyper](https://github.com/vntyper-org/VNtyper) MUC1-VNTR genotyping on sequencing
data submitted through the browser. It holds no analysis code of its own: it is the Docker Compose stack, the
Nginx reverse proxy, the Certbot sidecar and the deployment script that tie the pipeline
and the web interface together. Research use only.

The API and the Celery workers run the VNtyper container image, pinned by digest in
`docker-compose.yml`. Two git submodules supply the source:

| Path | Repository | Role |
| --- | --- | --- |
| `backend/` | [vntyper-org/VNtyper](https://github.com/vntyper-org/VNtyper) | Pipeline, FastAPI app and Celery tasks |
| `frontend/` | [vntyper-org/vntyper-online-frontend](https://github.com/vntyper-org/vntyper-online-frontend) | Browser interface served at vntyper.org |

The stack runs Redis, PostgreSQL, the API, three Celery workers, Celery beat, the
frontend, Nginx and Certbot. [Architecture](docs/ARCHITECTURE.md) lists each service and
the repository layout.

## Requirements

- Docker with the Compose plugin (`docker compose`) or standalone `docker-compose`
- Git
- For production: a domain whose DNS points at the server, and ports 80 and 443 open

## Quickstart (local development)

```bash
git clone --recurse-submodules https://github.com/vntyper-org/vntyper-online-backend.git
cd vntyper-online-backend
cp .env.example .env.local
# Set REDIS_PASSWORD, POSTGRES_PASSWORD (both required), INPUT_VOLUME and OUTPUT_VOLUME
docker compose --env-file .env.local -f docker-compose.yml -f docker-compose.dev.yml up --build
```

The API then answers on `http://localhost:8000/api/health/` and reloads on changes under
`backend/docker/app`. Serve the interface with `cd frontend && python3 -m http.server 3000`
and open `http://localhost:3000`. [Development](docs/DEVELOPMENT.md) covers the dev
overrides, worker restarts and the lint targets.

## Production deployment

On the server, with `.env.production` filled in from `.env.example`:

```bash
sudo ./scripts/deploy.sh             # pull, update submodules, rebuild, restart
sudo ./scripts/deploy.sh --fix-perms --no-cache   # first deploy
```

[Deployment](docs/DEPLOYMENT.md) covers the environment file, image pinning and roll-forward,
Redis persistence, TLS certificates and troubleshooting.

## Checks

```bash
make lint       # hadolint, shellcheck, yamllint, actionlint, docker compose config
make security   # detect-secrets against .secrets.baseline
```

CI runs the same linters when configuration files change, Trivy config and filesystem
scans plus Gitleaks on every pull request to `main` and weekly, and a Trivy scan of the
proxy and Certbot images when they change and weekly.

## Related repositories

- [VNtyper](https://github.com/vntyper-org/VNtyper): the genotyping pipeline
  ([documentation](https://vntyper-org.github.io/VNtyper/))
- [vntyper-online-frontend](https://github.com/vntyper-org/vntyper-online-frontend): the web interface
- [vntyper-data](https://github.com/vntyper-org/vntyper-data): reference bundles used by VNtyper

## Citing

If you use the web service in your work, cite VNtyper: its repository carries a
[CITATION.cff](https://github.com/vntyper-org/VNtyper/blob/main/CITATION.cff) file, shown on
GitHub as "Cite this repository".

## License

[MIT](LICENSE)
