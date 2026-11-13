# Development

## Setup

Clone with submodules; the backend image is built from `backend/` and the dev overrides
mount `backend/docker/app` into the containers:

```bash
git clone --recurse-submodules https://github.com/vntyper-org/vntyper-online-backend.git
```

In an existing clone without submodules, run `git submodule update --init --recursive`
(or `make submodules-init`).

Copy `.env.example` to `.env.local` and set at least `REDIS_PASSWORD` and
`POSTGRES_PASSWORD` (neither has a default; `docker compose` refuses to start without them),
`INPUT_VOLUME` and `OUTPUT_VOLUME`. `.env.local` is gitignored.

## Run the stack with auto-reload

```bash
# Terminal 1: API and workers
docker compose --env-file .env.local -f docker-compose.yml -f docker-compose.dev.yml up --build

# Terminal 2: frontend
cd frontend && python3 -m http.server 3000
```

Open `http://localhost:3000`; the frontend calls the API at `http://localhost:8000/api`.
CORS is enabled for `localhost:3000`, so no proxy is needed.

`docker-compose.dev.yml`:

- runs `backend_api` with `fastapi dev`, which reloads on changes under
  `backend/docker/app` (about 2-10 s); frontend changes need only a browser reload;
- tags the local build `vntyper-online:dev` instead of the digest-pinned release image;
- places `proxy` and `frontend` in the `production` profile, so they do not start;
- disables restart policies for easier debugging. Security hardening from the base file
  stays in place.

Celery does not auto-reload. Restart the workers after changing task code:

```bash
docker compose --env-file .env.local -f docker-compose.yml -f docker-compose.dev.yml \
  restart backend_worker backend_worker_vntyper backend_worker_vntyper_long
```

`make dev-shell` opens a shell in the API container, `make dev-redis` a Redis CLI, and
`make health` checks the API, the proxy and Redis.

## Checks

`make help` lists all targets. The ones CI mirrors:

| Target | Tool |
| --- | --- |
| `make lint-docker` | hadolint on `proxy/Dockerfile` and `certbot/Dockerfile` |
| `make lint-shell` | shellcheck on all `*.sh` outside the submodules |
| `make lint-yaml` | yamllint |
| `make lint-actions` | actionlint on `.github/workflows` |
| `make lint-compose` | `docker compose config` for the base and dev files (reads `ENV_FILE`, default `.env.local`) |
| `make security` | detect-secrets against `.secrets.baseline` |

`make lint` runs all five linters. Without a local `hadolint` or `shellcheck`, the
Makefile runs the official Docker image at the version CI uses. `make pre-commit-install` installs the hooks from
`.pre-commit-config.yaml`.
