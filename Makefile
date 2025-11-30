# Makefile for VNtyper Online Backend
# ============================================================================
# Provides convenient commands for linting, security scanning, Docker
# operations, and development workflows.
#
# Usage:
#   make help          - Show available targets
#   make lint          - Run all linters
#   make security      - Run security scans
#   make dev-up        - Start development environment
# ============================================================================

.PHONY: help lint lint-docker lint-shell lint-yaml lint-actions lint-compose \
        security security-secrets security-trivy \
        pre-commit pre-commit-install pre-commit-update \
        dev-up dev-down dev-logs dev-build dev-restart \
        prod-up prod-down prod-logs prod-build \
        clean validate format

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Environment file (default to local)
ENV_FILE ?= .env.local

# ============================================================================
# Help
# ============================================================================

help: ## Show this help message
	@echo "$(BLUE)VNtyper Online Backend - Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(YELLOW)Linting:$(NC)"
	@grep -E '^(lint[a-zA-Z_-]*):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Security:$(NC)"
	@grep -E '^(security[a-zA-Z_-]*):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Pre-commit:$(NC)"
	@grep -E '^(pre-commit[a-zA-Z_-]*):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@grep -E '^(dev[a-zA-Z_-]*):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Production:$(NC)"
	@grep -E '^(prod[a-zA-Z_-]*):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Other:$(NC)"
	@grep -E '^(clean|validate|format):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ============================================================================
# Linting Targets
# ============================================================================

lint: lint-docker lint-shell lint-yaml lint-actions lint-compose ## Run all linters
	@echo "$(GREEN)All linting checks passed!$(NC)"

lint-docker: ## Lint Dockerfiles with hadolint
	@echo "$(BLUE)Linting Dockerfiles...$(NC)"
	@hadolint --config .hadolint.yaml proxy/Dockerfile || true
	@hadolint --config .hadolint.yaml certbot/Dockerfile || true

lint-shell: ## Lint shell scripts with shellcheck
	@echo "$(BLUE)Linting shell scripts...$(NC)"
	@find . -name '*.sh' \
		-not -path './backend/*' \
		-not -path './frontend/*' \
		-not -path './node_modules/*' \
		-exec shellcheck --rcfile=.shellcheckrc {} +

lint-yaml: ## Lint YAML files with yamllint
	@echo "$(BLUE)Linting YAML files...$(NC)"
	@yamllint -c .yamllint.yml .

lint-actions: ## Lint GitHub Actions workflows with actionlint
	@echo "$(BLUE)Linting GitHub Actions...$(NC)"
	@actionlint

lint-compose: ## Validate Docker Compose files
	@echo "$(BLUE)Validating Docker Compose files...$(NC)"
	@set -a && source $(ENV_FILE) && set +a && \
		docker compose -f docker-compose.yml config --quiet && \
		echo "  docker-compose.yml: $(GREEN)OK$(NC)"
	@set -a && source $(ENV_FILE) && set +a && \
		docker compose -f docker-compose.yml -f docker-compose.dev.yml config --quiet && \
		echo "  docker-compose.dev.yml: $(GREEN)OK$(NC)"
	@echo "$(GREEN)Docker Compose validation passed!$(NC)"

# ============================================================================
# Security Targets
# ============================================================================

security: security-secrets ## Run all security scans
	@echo "$(GREEN)Security scans completed!$(NC)"

security-secrets: ## Scan for secrets with detect-secrets
	@echo "$(BLUE)Scanning for secrets...$(NC)"
	@detect-secrets scan --baseline .secrets.baseline || true

security-trivy: ## Scan Docker images with Trivy (requires built images)
	@echo "$(BLUE)Scanning Docker images with Trivy...$(NC)"
	@trivy image vntyper:latest || true
	@trivy image vntyper_proxy:2.0.0 || true
	@trivy image vntyper_frontend:2.0.0 || true

security-audit: ## Run comprehensive security audit
	@echo "$(BLUE)Running security audit...$(NC)"
	@echo "Checking for secrets..."
	@detect-secrets scan --baseline .secrets.baseline
	@echo ""
	@echo "Checking Dockerfiles..."
	@hadolint --config .hadolint.yaml proxy/Dockerfile
	@hadolint --config .hadolint.yaml certbot/Dockerfile

# ============================================================================
# Pre-commit Targets
# ============================================================================

pre-commit: ## Run pre-commit hooks on all files
	@echo "$(BLUE)Running pre-commit hooks...$(NC)"
	@pre-commit run --all-files

pre-commit-install: ## Install pre-commit hooks
	@echo "$(BLUE)Installing pre-commit hooks...$(NC)"
	@pre-commit install
	@echo "$(GREEN)Pre-commit hooks installed!$(NC)"

pre-commit-update: ## Update pre-commit hooks to latest versions
	@echo "$(BLUE)Updating pre-commit hooks...$(NC)"
	@pre-commit autoupdate
	@echo "$(GREEN)Pre-commit hooks updated!$(NC)"

# ============================================================================
# Development Environment
# ============================================================================

dev-up: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	@./dev.sh up

dev-down: ## Stop development environment
	@echo "$(BLUE)Stopping development environment...$(NC)"
	@./dev.sh down

dev-logs: ## View development logs (follow mode)
	@./dev.sh logs

dev-build: ## Rebuild development containers
	@echo "$(BLUE)Rebuilding development containers...$(NC)"
	@./dev.sh build

dev-restart: ## Restart development services
	@echo "$(BLUE)Restarting development services...$(NC)"
	@./dev.sh down && ./dev.sh up

dev-shell: ## Open shell in backend API container
	@docker exec -it vntyper_backend_api bash

dev-redis: ## Open Redis CLI
	@set -a && source $(ENV_FILE) && set +a && \
		docker exec -it vntyper_online_redis redis-cli -a "$${REDIS_PASSWORD}"

# ============================================================================
# Production Environment
# ============================================================================

prod-up: ## Start production environment
	@echo "$(BLUE)Starting production environment...$(NC)"
	@set -a && source .env.production && set +a && \
		docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

prod-down: ## Stop production environment
	@echo "$(BLUE)Stopping production environment...$(NC)"
	@set -a && source .env.production && set +a && \
		docker compose -f docker-compose.yml -f docker-compose.prod.yml down

prod-logs: ## View production logs (follow mode)
	@set -a && source .env.production && set +a && \
		docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f

prod-build: ## Build production containers
	@echo "$(BLUE)Building production containers...$(NC)"
	@set -a && source .env.production && set +a && \
		docker compose -f docker-compose.yml -f docker-compose.prod.yml build

prod-status: ## Show production container status
	@set -a && source .env.production && set +a && \
		docker compose -f docker-compose.yml -f docker-compose.prod.yml ps

# ============================================================================
# Utilities
# ============================================================================

validate: lint-compose ## Validate all configuration files
	@echo "$(GREEN)All configurations valid!$(NC)"

format: ## Format files (trailing whitespace, line endings)
	@echo "$(BLUE)Formatting files...$(NC)"
	@pre-commit run trailing-whitespace --all-files || true
	@pre-commit run end-of-file-fixer --all-files || true
	@pre-commit run mixed-line-ending --all-files || true
	@echo "$(GREEN)Formatting complete!$(NC)"

clean: ## Clean up Docker resources
	@echo "$(BLUE)Cleaning up Docker resources...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)Cleanup complete!$(NC)"

clean-all: ## Deep clean (includes volumes - CAUTION)
	@echo "$(RED)WARNING: This will remove all Docker volumes!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	@docker system prune -af --volumes
	@echo "$(GREEN)Deep cleanup complete!$(NC)"

# ============================================================================
# Submodules
# ============================================================================

submodules-init: ## Initialize git submodules
	@echo "$(BLUE)Initializing submodules...$(NC)"
	@git submodule update --init --recursive
	@echo "$(GREEN)Submodules initialized!$(NC)"

submodules-update: ## Update submodules to latest
	@echo "$(BLUE)Updating submodules...$(NC)"
	@git submodule update --remote --merge
	@echo "$(GREEN)Submodules updated!$(NC)"

# ============================================================================
# Health Checks
# ============================================================================

health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@curl -sf http://localhost:8000/api/health/ && echo "  Backend API: $(GREEN)OK$(NC)" || echo "  Backend API: $(RED)DOWN$(NC)"
	@curl -sf http://localhost/health && echo "  Proxy: $(GREEN)OK$(NC)" || echo "  Proxy: $(RED)DOWN$(NC)"
	@docker exec vntyper_online_redis redis-cli ping > /dev/null 2>&1 && echo "  Redis: $(GREEN)OK$(NC)" || echo "  Redis: $(RED)DOWN$(NC)"
