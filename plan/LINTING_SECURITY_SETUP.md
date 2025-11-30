# Linting, Security Checks, and CI/CD Setup Plan

**Date:** 2025-11-30
**Scope:** Main repository only (not submodules: `backend/`, `frontend/`)
**Status:** Planning

## Table of Contents

1. [Overview](#overview)
2. [Files to Lint](#files-to-lint)
3. [Tool Selection](#tool-selection)
4. [Implementation Plan](#implementation-plan)
5. [Configuration Files](#configuration-files)
6. [GitHub Actions Workflows](#github-actions-workflows)
7. [Pre-commit Hooks](#pre-commit-hooks)
8. [Dependabot Configuration](#dependabot-configuration)
9. [Security Best Practices](#security-best-practices)
10. [Sources](#sources)

---

## Overview

This plan establishes linting, security scanning, and automated dependency updates for the vntyper-online-backend repository. The goal is to:

- **Catch errors early** via pre-commit hooks
- **Ensure security** via container image scanning and secret detection
- **Automate dependency updates** via Dependabot
- **Maintain code quality** via CI/CD pipelines

### Guiding Principles

1. **Least privilege** - GitHub Actions use minimal required permissions
2. **Pin dependencies** - Use SHA hashes for actions, not tags
3. **Fail fast** - Block PRs on critical security issues
4. **Automation** - Reduce manual maintenance burden

---

## Files to Lint

### Main Repository Files (Scope)

| File Type | Files | Linting Tool |
|-----------|-------|--------------|
| Dockerfiles | `proxy/Dockerfile`, `certbot/Dockerfile` | Hadolint |
| Docker Compose | `docker-compose.yml`, `docker-compose.dev.yml`, `docker-compose.prod.yml` | DCLint, `docker compose config` |
| Shell Scripts | `proxy/entrypoint.sh`, `certbot/entrypoint.sh` | ShellCheck |
| Nginx Config | `proxy/nginx.conf.template.*` | nginx -t (syntax check) |
| YAML Files | `.github/workflows/*.yml`, `docker-compose*.yml` | yamllint |
| GitHub Actions | `.github/workflows/*.yml` | actionlint |

### Excluded (Submodules)

- `backend/` - Has its own CI/CD workflows
- `frontend/` - Has its own CI/CD workflows

---

## Tool Selection

### Linting Tools

| Tool | Purpose | Why Chosen |
|------|---------|------------|
| [Hadolint](https://github.com/hadolint/hadolint) | Dockerfile linting | Industry standard, integrates ShellCheck for RUN commands |
| [ShellCheck](https://github.com/koalaman/shellcheck) | Shell script linting | De facto standard for bash/sh linting |
| [DCLint](https://github.com/zavoloklom/docker-compose-linter) | Docker Compose linting | Schema validation + best practice rules |
| [yamllint](https://github.com/adrienverge/yamllint) | YAML linting | Syntax and formatting validation |
| [actionlint](https://github.com/rhysd/actionlint) | GitHub Actions linting | Catches workflow errors, integrates shellcheck/pyflakes |

### Security Tools

| Tool | Purpose | Why Chosen |
|------|---------|------------|
| [Trivy](https://github.com/aquasecurity/trivy) | Container vulnerability scanning | Comprehensive, fast, supports SARIF for GitHub Security tab |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | Secret detection | Detects hardcoded secrets in git history |
| [CodeQL](https://github.com/github/codeql-action) | GitHub Actions security analysis | Native GitHub integration, catches workflow vulnerabilities |

### Dependency Management

| Tool | Purpose | Why Chosen |
|------|---------|------------|
| [Dependabot](https://docs.github.com/en/code-security/dependabot) | Automated dependency updates | Native GitHub integration, supports Docker/docker-compose/actions |

---

## Implementation Plan

### Phase 1: Foundation Setup

1. Create `.github/` directory structure
2. Add Dependabot configuration
3. Add basic GitHub Actions workflow for linting

### Phase 2: Pre-commit Hooks

1. Create `.pre-commit-config.yaml`
2. Document pre-commit installation for developers

### Phase 3: Security Scanning

1. Add Trivy container scanning workflow
2. Add Gitleaks secret scanning
3. Enable CodeQL for Actions workflow analysis

### Phase 4: Advanced CI/CD

1. Add build verification workflow
2. Add docker-compose validation
3. Add SARIF upload to GitHub Security tab

---

## Configuration Files

### 1. Hadolint Configuration (`.hadolint.yaml`)

```yaml
# .hadolint.yaml
# Hadolint configuration for Dockerfile linting
# https://github.com/hadolint/hadolint

# Failure threshold (error, warning, info, style, ignore)
failure-threshold: warning

# Trusted registries (images from these registries won't trigger DL3026)
trustedRegistries:
  - docker.io
  - ghcr.io

# Rules to ignore globally
ignored:
  # DL3008: Pin versions in apt-get install (difficult with security updates)
  - DL3008
  # DL3018: Pin versions in apk add (difficult with security updates)
  - DL3018

# Override severity for specific rules
override:
  warning:
    - DL3015  # Avoid additional packages with apt-get install
  info:
    - DL3059  # Multiple consecutive RUN instructions
```

### 2. ShellCheck Configuration (`.shellcheckrc`)

```bash
# .shellcheckrc
# ShellCheck configuration
# https://github.com/koalaman/shellcheck

# Default shell dialect (sh, bash, dash, ksh)
shell=bash

# Enable all optional checks
enable=all

# Disable specific checks
# SC2086: Double quote to prevent globbing (sometimes intentional)
# SC1091: Not following sourced files (external files)
disable=SC1091

# Severity level (error, warning, info, style)
severity=warning
```

### 3. yamllint Configuration (`.yamllint.yml`)

```yaml
# .yamllint.yml
# yamllint configuration
# https://github.com/adrienverge/yamllint

extends: default

rules:
  # Allow long lines for URLs and commands
  line-length:
    max: 150
    allow-non-breakable-words: true
    allow-non-breakable-inline-mappings: true

  # Require document start marker (---)
  document-start: disable

  # Allow multiple spaces for alignment
  comments:
    min-spaces-from-content: 1

  # Indentation settings
  indentation:
    spaces: 2
    indent-sequences: true

  # Truthy values
  truthy:
    allowed-values: ['true', 'false', 'yes', 'no', 'on', 'off']

# Ignore submodules
ignore: |
  backend/
  frontend/
  node_modules/
```

### 4. DCLint Configuration (`.dclint.yml`)

```yaml
# .dclint.yml
# Docker Compose Linter configuration
# https://github.com/zavoloklom/docker-compose-linter

rules:
  # Require explicit container names
  no-duplicate-container-names: error

  # Prevent duplicate port bindings
  no-duplicate-exported-ports: error

  # Warn about unbound ports (0.0.0.0)
  no-unbound-port-interfaces: warning

  # Modern docker-compose shouldn't have version field
  no-version-field: warning

  # Require quotes around port strings
  require-quotes-in-ports: warning

# Files to lint
files:
  - docker-compose.yml
  - docker-compose.dev.yml
  - docker-compose.prod.yml
```

### 5. actionlint Configuration (`.github/actionlint.yaml`)

```yaml
# .github/actionlint.yaml
# actionlint configuration
# https://github.com/rhysd/actionlint

# Self-hosted runner labels (if any)
self-hosted-runner:
  labels: []

# Configuration variables accessible via vars context
config-variables: []
```

---

## GitHub Actions Workflows

### 1. Linting Workflow (`.github/workflows/lint.yml`)

```yaml
# .github/workflows/lint.yml
name: Lint

on:
  push:
    branches: [main]
    paths:
      - '**.yml'
      - '**.yaml'
      - '**.sh'
      - '**/Dockerfile'
      - 'proxy/**'
      - 'certbot/**'
  pull_request:
    branches: [main]
    paths:
      - '**.yml'
      - '**.yaml'
      - '**.sh'
      - '**/Dockerfile'
      - 'proxy/**'
      - 'certbot/**'

# Restrict permissions to minimum required
permissions:
  contents: read

jobs:
  hadolint:
    name: Lint Dockerfiles
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Run Hadolint on proxy/Dockerfile
        uses: hadolint/hadolint-action@54c9adbab1582c2ef04b2016b760714a4bfde3cf # v3.1.0
        with:
          dockerfile: proxy/Dockerfile
          failure-threshold: warning

      - name: Run Hadolint on certbot/Dockerfile
        uses: hadolint/hadolint-action@54c9adbab1582c2ef04b2016b760714a4bfde3cf # v3.1.0
        with:
          dockerfile: certbot/Dockerfile
          failure-threshold: warning

  shellcheck:
    name: Lint Shell Scripts
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
        with:
          scandir: '.'
          severity: warning
          ignore_paths: 'backend frontend node_modules'

  yaml-lint:
    name: Lint YAML files
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Run yamllint
        uses: ibiqlik/action-yamllint@2576378a8e339169678f9939646ee3ee325e845c # v3.1.1
        with:
          file_or_dir: '.'
          config_file: '.yamllint.yml'

  actionlint:
    name: Lint GitHub Actions
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Run actionlint
        uses: raven-actions/actionlint@01fce4f43a270a612932cb1c64d40505a97f2f1f # v2.0.0
        with:
          fail-on-error: true

  docker-compose-lint:
    name: Lint Docker Compose
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Validate docker-compose.yml syntax
        run: docker compose -f docker-compose.yml config --quiet

      - name: Validate docker-compose.dev.yml syntax
        run: docker compose -f docker-compose.yml -f docker-compose.dev.yml config --quiet
        env:
          INPUT_VOLUME: /tmp/input
          OUTPUT_VOLUME: /tmp/output

      - name: Validate docker-compose.prod.yml syntax
        run: docker compose -f docker-compose.yml -f docker-compose.prod.yml config --quiet
        env:
          INPUT_VOLUME: /tmp/input
          OUTPUT_VOLUME: /tmp/output
```

### 2. Security Scanning Workflow (`.github/workflows/security.yml`)

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Run weekly on Sundays at midnight
    - cron: '0 0 * * 0'

permissions:
  contents: read
  security-events: write

jobs:
  trivy-dockerfile:
    name: Trivy Config Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Run Trivy vulnerability scanner (config mode)
        uses: aquasecurity/trivy-action@915b19bbe73b92a6cf82a1bc12b087c9a19a5fe2 # 0.28.0
        with:
          scan-type: 'config'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-config-results.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'
          # Ignore submodules
          skip-dirs: 'backend,frontend,node_modules'

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@1b549b9259bda1cb5ddde3b41741a82a2d15a841 # v3.28.13
        with:
          sarif_file: 'trivy-config-results.sarif'

  gitleaks:
    name: Secret Detection
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@ff98106e4c7b2bc287b24eaf42907196329070c7 # v2.3.7
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  codeql-actions:
    name: CodeQL Actions Analysis
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Initialize CodeQL
        uses: github/codeql-action/init@1b549b9259bda1cb5ddde3b41741a82a2d15a841 # v3.28.13
        with:
          languages: actions
          queries: security-extended

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@1b549b9259bda1cb5ddde3b41741a82a2d15a841 # v3.28.13
        with:
          category: "/language:actions"
```

### 3. Container Image Scan Workflow (`.github/workflows/container-scan.yml`)

```yaml
# .github/workflows/container-scan.yml
name: Container Image Scan

on:
  push:
    branches: [main]
    paths:
      - 'proxy/**'
      - 'certbot/**'
  pull_request:
    branches: [main]
    paths:
      - 'proxy/**'
      - 'certbot/**'

permissions:
  contents: read
  security-events: write

jobs:
  build-and-scan:
    name: Build and Scan Images
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - context: proxy
            image: vntyper-proxy
          - context: certbot
            image: vntyper-certbot
    steps:
      - name: Checkout code
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Build ${{ matrix.image }} image
        run: |
          docker build -t ${{ matrix.image }}:${{ github.sha }} \
            -f ${{ matrix.context }}/Dockerfile \
            ${{ matrix.context }}/

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@915b19bbe73b92a6cf82a1bc12b087c9a19a5fe2 # 0.28.0
        with:
          image-ref: '${{ matrix.image }}:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-${{ matrix.image }}-results.sarif'
          severity: 'CRITICAL,HIGH'
          ignore-unfixed: true

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@1b549b9259bda1cb5ddde3b41741a82a2d15a841 # v3.28.13
        with:
          sarif_file: 'trivy-${{ matrix.image }}-results.sarif'
          category: 'container-${{ matrix.image }}'
```

---

## Pre-commit Hooks

### Configuration (`.pre-commit-config.yaml`)

```yaml
# .pre-commit-config.yaml
# Pre-commit hooks configuration
# Install: pip install pre-commit && pre-commit install
# Run manually: pre-commit run --all-files
# https://pre-commit.com/

# Minimum pre-commit version
minimum_pre_commit_version: '3.0.0'

# Default settings
default_stages: [pre-commit]

repos:
  # General file checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
        exclude: ^(backend|frontend)/
      - id: end-of-file-fixer
        exclude: ^(backend|frontend)/
      - id: check-yaml
        exclude: ^(backend|frontend)/
        args: ['--unsafe']  # Allow custom tags
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: detect-private-key
      - id: mixed-line-ending
        args: ['--fix=lf']
        exclude: ^(backend|frontend)/

  # Dockerfile linting with Hadolint
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker
        entry: hadolint
        files: Dockerfile
        exclude: ^(backend|frontend)/

  # Shell script linting with ShellCheck
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck
        exclude: ^(backend|frontend)/
        args: ['--severity=warning']

  # YAML linting
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        exclude: ^(backend|frontend)/
        args: ['-c', '.yamllint.yml']

  # GitHub Actions linting
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.4
    hooks:
      - id: actionlint

  # Docker Compose validation
  - repo: https://github.com/IamTheFij/docker-pre-commit
    rev: v3.0.1
    hooks:
      - id: docker-compose-check
        files: docker-compose.*\.yml$
```

### Developer Setup Instructions

Add to `README.md` or create `CONTRIBUTING.md`:

```markdown
## Development Setup

### Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality. To set up:

1. Install pre-commit:
   ```bash
   pip install pre-commit
   ```

2. Install the hooks:
   ```bash
   pre-commit install
   ```

3. (Optional) Run on all files:
   ```bash
   pre-commit run --all-files
   ```

Hooks will run automatically on `git commit`. To bypass (not recommended):
```bash
git commit --no-verify
```
```

---

## Dependabot Configuration

### Configuration (`.github/dependabot.yml`)

```yaml
# .github/dependabot.yml
# Dependabot configuration for automated dependency updates
# https://docs.github.com/en/code-security/dependabot/dependabot-version-updates

version: 2

registries:
  # Docker Hub (public, no auth needed but explicit config)
  dockerhub:
    type: docker-registry
    url: https://registry.hub.docker.com
    replaces-base: true

updates:
  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/Berlin"
    commit-message:
      prefix: "ci(deps)"
    labels:
      - "dependencies"
      - "github-actions"
    open-pull-requests-limit: 5
    groups:
      github-actions:
        patterns:
          - "*"

  # Docker - Main repo Dockerfiles
  - package-ecosystem: "docker"
    directory: "/proxy"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/Berlin"
    commit-message:
      prefix: "build(deps)"
    labels:
      - "dependencies"
      - "docker"
    open-pull-requests-limit: 3

  - package-ecosystem: "docker"
    directory: "/certbot"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/Berlin"
    commit-message:
      prefix: "build(deps)"
    labels:
      - "dependencies"
      - "docker"
    open-pull-requests-limit: 3

  # Docker Compose
  - package-ecosystem: "docker-compose"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/Berlin"
    commit-message:
      prefix: "build(deps)"
    labels:
      - "dependencies"
      - "docker-compose"
    open-pull-requests-limit: 5

  # Git Submodules
  - package-ecosystem: "gitsubmodule"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "Europe/Berlin"
    commit-message:
      prefix: "chore(deps)"
    labels:
      - "dependencies"
      - "submodules"
    open-pull-requests-limit: 2
```

---

## Security Best Practices

### Workflow Security Checklist

- [x] **Minimal permissions** - Use `permissions:` block with least privilege
- [x] **Pin actions by SHA** - Use full commit SHA, not tags (prevents supply chain attacks)
- [x] **No secrets in logs** - Use `${{ secrets.* }}` for sensitive values
- [x] **Restrict triggers** - Limit `pull_request_target` and `workflow_run` usage
- [x] **SARIF upload** - Send security findings to GitHub Security tab
- [x] **Dependabot** - Automated security updates for dependencies
- [x] **CodeQL** - Native GitHub Actions security analysis

### Repository Security Settings

Enable these settings in GitHub repository settings:

1. **Settings > Code security and analysis**
   - Enable Dependabot alerts
   - Enable Dependabot security updates
   - Enable Secret scanning
   - Enable Push protection (blocks commits with secrets)

2. **Settings > Branches > Branch protection rules** (for `main`)
   - Require pull request reviews
   - Require status checks to pass (lint, security workflows)
   - Require branches to be up to date
   - Include administrators

### Secrets Management

Never commit:
- `.env.local` / `.env.production` (already in `.gitignore`)
- API keys, tokens, passwords
- SSL certificates/private keys

Use GitHub Secrets for CI/CD:
- Repository secrets for repo-specific values
- Organization secrets for shared values
- Environment secrets for deployment-specific values

---

## Implementation Checklist

### Phase 1: Foundation (Day 1)
- [ ] Create `.github/` directory
- [ ] Create `.github/dependabot.yml`
- [ ] Create `.hadolint.yaml`
- [ ] Create `.shellcheckrc`
- [ ] Create `.yamllint.yml`
- [ ] Create `.github/actionlint.yaml`

### Phase 2: GitHub Actions (Day 1-2)
- [ ] Create `.github/workflows/lint.yml`
- [ ] Create `.github/workflows/security.yml`
- [ ] Create `.github/workflows/container-scan.yml`
- [ ] Test workflows on a PR

### Phase 3: Pre-commit (Day 2)
- [ ] Create `.pre-commit-config.yaml`
- [ ] Test pre-commit locally
- [ ] Update documentation

### Phase 4: Repository Settings (Day 2)
- [ ] Enable Dependabot alerts
- [ ] Enable secret scanning
- [ ] Configure branch protection rules

---

## Sources

### Linting Tools
- [Hadolint - Dockerfile linter](https://hadolint.com/)
- [Hadolint GitHub Action](https://github.com/hadolint/hadolint-action)
- [ShellCheck - Shell script linter](https://github.com/koalaman/shellcheck)
- [ShellCheck Pre-commit Hook](https://github.com/koalaman/shellcheck-precommit)
- [DCLint - Docker Compose Linter](https://github.com/zavoloklom/docker-compose-linter)
- [yamllint](https://github.com/adrienverge/yamllint)
- [actionlint - GitHub Actions linter](https://github.com/rhysd/actionlint)

### Security Tools
- [Trivy - Container Scanner](https://github.com/aquasecurity/trivy)
- [Trivy GitHub Action](https://github.com/aquasecurity/trivy-action)
- [Gitleaks - Secret Detection](https://github.com/gitleaks/gitleaks)
- [CodeQL Actions Analysis](https://github.blog/changelog/2025-04-22-github-actions-workflow-security-analysis-with-codeql-is-now-generally-available/)

### Best Practices
- [GitHub Actions Security Best Practices](https://statusneo.com/best-practices-for-securing-github-actions-workflows/)
- [GitHub Secure Use Reference](https://docs.github.com/en/actions/reference/secure-use)
- [Dependabot Docker Compose Support](https://github.blog/changelog/2025-02-25-dependabot-version-updates-now-support-docker-compose-in-general-availability/)
- [Dependabot Options Reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [Pre-commit Hooks](https://pre-commit.com/hooks.html)
- [Dockerfile Best Practices](https://www.kristhecodingunicorn.com/post/dockerfile-linting-with-hadolint/)
