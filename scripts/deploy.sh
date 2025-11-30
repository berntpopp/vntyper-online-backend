#!/bin/bash
# VNtyper Online - Production Deployment
# Usage: sudo ./scripts/deploy.sh [--no-cache] [--fix-perms] [--stop]
set -euo pipefail

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${DEPLOY_DIR}/.env.production"
COMPOSE="docker-compose --env-file ${ENV_FILE} -f docker-compose.yml -f docker-compose.prod.yml"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1" >&2; exit 1; }

# Check requirements
[[ $EUID -eq 0 ]] || error "Run with sudo"
[[ -f "$ENV_FILE" ]] || error "Missing ${ENV_FILE}"
command -v docker-compose &>/dev/null || error "docker-compose not found"

# Parse args
NO_CACHE=""
FIX_PERMS=false
STOP_ONLY=false
for arg in "$@"; do
    case $arg in
        --no-cache) NO_CACHE="--no-cache" ;;
        --fix-perms) FIX_PERMS=true ;;
        --stop) STOP_ONLY=true ;;
        --help|-h) echo "Usage: sudo $0 [--no-cache] [--fix-perms] [--stop]"; exit 0 ;;
        *) error "Unknown option: $arg" ;;
    esac
done

cd "$DEPLOY_DIR"

# Fix permissions for non-root containers (certbot=1000)
if [[ "$FIX_PERMS" == true ]]; then
    info "Fixing permissions..."
    mkdir -p /etc/ssl/certs/vntyper /var/www/certbot
    chown -R 1000:1000 /etc/ssl/certs/vntyper /var/www/certbot
fi

# Stop only
if [[ "$STOP_ONLY" == true ]]; then
    info "Stopping services..."
    $COMPOSE down --remove-orphans
    info "Stopped."
    exit 0
fi

# Pull
info "Pulling code..."
git pull --ff-only
git submodule update --init --recursive

# Deploy
info "Stopping services..."
$COMPOSE down --remove-orphans

info "Building${NO_CACHE:+ (no-cache)}..."
$COMPOSE build $NO_CACHE

info "Starting..."
$COMPOSE up -d

# Verify
info "Waiting for health..."
for _ in {1..30}; do
    curl -sf http://localhost:8000/api/health/ &>/dev/null && break
    sleep 2
done

info "Status:"
$COMPOSE ps --format "table {{.Name}}\t{{.Status}}"

# Cleanup
docker image prune -f &>/dev/null

info "Done!"
