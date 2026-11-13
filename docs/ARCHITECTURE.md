# Architecture

VNtyper Online is a set of containers orchestrated with Docker Compose.
`docker-compose.yml` is the base configuration, `docker-compose.prod.yml` adds the
production overrides (published ports 80/443, Certbot, digest-pinned images) and
`docker-compose.dev.yml` the development overrides (see [Development](DEVELOPMENT.md)).

## Services

| Service | Container | Role |
| --- | --- | --- |
| `redis` | `vntyper_online_redis` | Celery broker and result store, usage counters |
| `postgres` | `vntyper_online_postgres` | Anonymous research data donations (only with `ENABLE_DONATIONS=true`) |
| `backend_api` | `vntyper_backend_api` | FastAPI application, bound to `127.0.0.1:8000` |
| `backend_worker_vntyper` | `vntyper_online_worker_vntyper` | Celery worker for VNtyper jobs (normal mode), queue `vntyper_queue` |
| `backend_worker_vntyper_long` | `vntyper_online_worker_vntyper_long` | Celery worker for long-running adVNTR jobs, queue `vntyper_long_queue` |
| `backend_worker` | `vntyper_online_worker` | Celery worker for other tasks (email, cleanup, cohort analysis), queue `celery` |
| `backend_beat` | `vntyper_online_beat` | Celery beat task scheduler |
| `frontend` | `vntyper_online_frontend` | Static frontend files served by Nginx |
| `proxy` | `vntyper_proxy` | Nginx reverse proxy: TLS termination and routing to the API and frontend |
| `certbot` | `vntyper_certbot` | Let's Encrypt certificate issuance and renewal (production only) |

The API, workers and beat all run the VNtyper image (`VNTYPER_IMAGE`, digest-pinned by
default; see [Backend image pinning](DEPLOYMENT.md#backend-image-pinning)). Every service
runs with `no-new-privileges`, drops all capabilities and adds back only what it needs,
and has resource limits; the header of `docker-compose.yml` lists the hardening applied.

## Repository layout

```text
vntyper-online-backend/
├── backend/                 # Submodule: vntyper-org/VNtyper (API, workers, pipeline)
├── frontend/                # Submodule: vntyper-org/vntyper-online-frontend
├── proxy/                   # Nginx reverse proxy image
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── nginx.conf.template.http
│   ├── nginx.conf.template.ssl
│   └── nginx.conf.template.acme
├── certbot/                 # Certbot image for TLS certificates
│   ├── Dockerfile
│   └── entrypoint.sh
├── scripts/
│   ├── deploy.sh            # Production deployment
│   └── benchmark/           # Online-versus-local benchmark harness
├── docker-compose.yml       # Base configuration
├── docker-compose.dev.yml   # Development overrides
├── docker-compose.prod.yml  # Production overrides
├── .env.example             # Template for .env.local and .env.production (both gitignored)
└── Makefile                 # Lint, security and compose helpers
```
