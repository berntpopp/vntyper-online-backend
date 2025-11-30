#!/bin/bash
# =============================================================================
# VNtyper Online - Production Deployment Script
# =============================================================================
# Usage: sudo ./scripts/deploy.sh [OPTIONS]
#
# Options:
#   --no-cache    Force rebuild without cache
#   --fix-perms   Fix host directory permissions (run once after upgrade)
#   --pull-only   Only pull code, don't restart services
#   --help        Show this help message
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_DIR="${DEPLOY_DIR:-/var/www/vntyper/vntyper-online-backend}"
ENV_FILE="${ENV_FILE:-.env.production}"
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.yml"

# Parse arguments
NO_CACHE=""
FIX_PERMS=false
PULL_ONLY=false

for arg in "$@"; do
    case $arg in
        --no-cache)
            NO_CACHE="--no-cache"
            ;;
        --fix-perms)
            FIX_PERMS=true
            ;;
        --pull-only)
            PULL_ONLY=true
            ;;
        --help)
            head -17 "$0" | tail -14
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

fix_permissions() {
    log_info "Fixing host directory permissions for non-root containers..."

    # Certbot directories (uid 1000)
    mkdir -p /etc/ssl/certs/vntyper /var/www/certbot
    chown -R 1000:1000 /etc/ssl/certs/vntyper /var/www/certbot
    chmod 755 /etc/ssl/certs/vntyper /var/www/certbot

    log_info "Permissions fixed for certbot (uid 1000)"
}

pull_code() {
    log_info "Pulling latest code..."
    cd "$DEPLOY_DIR"

    git fetch origin
    git pull origin "$(git rev-parse --abbrev-ref HEAD)"

    log_info "Updating submodules..."
    git submodule update --init --recursive
}

stop_services() {
    log_info "Stopping services..."
    cd "$DEPLOY_DIR"
    docker-compose --env-file "$ENV_FILE" $COMPOSE_FILES down
}

build_services() {
    log_info "Building services${NO_CACHE:+ (no cache)}..."
    cd "$DEPLOY_DIR"
    docker-compose --env-file "$ENV_FILE" $COMPOSE_FILES build $NO_CACHE
}

start_services() {
    log_info "Starting services..."
    cd "$DEPLOY_DIR"
    docker-compose --env-file "$ENV_FILE" $COMPOSE_FILES up -d
}

wait_for_health() {
    log_info "Waiting for services to be healthy..."
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf http://localhost:8000/api/health/ > /dev/null 2>&1; then
            log_info "Backend API is healthy"
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done

    if [[ $attempt -gt $max_attempts ]]; then
        log_warn "Backend health check timed out (may still be starting)"
    fi
}

show_status() {
    log_info "Service status:"
    cd "$DEPLOY_DIR"
    docker-compose --env-file "$ENV_FILE" $COMPOSE_FILES ps
}

cleanup_images() {
    log_info "Cleaning up unused Docker images..."
    docker image prune -f
}

# Main
main() {
    check_root

    log_info "VNtyper Online Deployment"
    log_info "========================="

    # Fix permissions if requested
    if [[ "$FIX_PERMS" == true ]]; then
        fix_permissions
    fi

    # Pull code
    pull_code

    # Exit if pull-only
    if [[ "$PULL_ONLY" == true ]]; then
        log_info "Pull complete (--pull-only specified)"
        exit 0
    fi

    # Deploy
    stop_services
    build_services
    start_services

    # Verify
    sleep 5
    wait_for_health
    show_status
    cleanup_images

    log_info "Deployment complete!"
}

main "$@"
