#!/bin/bash
# proxy/entrypoint.sh
# Nginx reverse proxy entrypoint with SSL support and auto-reload on certificate changes.
# Runs as non-root nginx user (from nginx-unprivileged base image).
# Environment variables are passed from Docker Compose.

set -e

# ==============================================================================
# Environment Variables (from Docker Compose)
# ==============================================================================
: "${SERVER_NAME:?SERVER_NAME environment variable is required}"
: "${ENVIRONMENT:=local}"
: "${CLIENT_MAX_BODY_SIZE:=100M}"

CERT_PATH="/etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/${SERVER_NAME}/privkey.pem"

# Template directory (nginx-unprivileged compatible)
TEMPLATE_DIR="/etc/nginx/templates"
CONF_DIR="/etc/nginx/conf.d"

# Function to generate Nginx configuration
generate_nginx_conf() {
    local template_file

    if [ "$ENVIRONMENT" = "production" ]; then
        if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
            echo "SSL certificates found. Configuring Nginx for HTTPS."
            template_file="${TEMPLATE_DIR}/nginx.conf.template.ssl"
        else
            echo "SSL certificates not found. Configuring Nginx for ACME challenge."
            template_file="${TEMPLATE_DIR}/nginx.conf.template.acme"
        fi
    else
        echo "Configuring Nginx for HTTP (development)."
        template_file="${TEMPLATE_DIR}/nginx.conf.template.http"
    fi

    # Generate config from template
    envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' \
        < "$template_file" > "${CONF_DIR}/default.conf"

    echo "Configuration generated: ${CONF_DIR}/default.conf"
}

# Warm up OCSP stapling cache by making a test connection
# This ensures OCSP response is cached before first client request
warmup_ocsp() {
    echo "Warming up OCSP stapling cache..."
    sleep 5  # Wait for nginx to fully start

    # Make a test connection to prime the OCSP cache
    # Using timeout to prevent hanging if something goes wrong
    if command -v openssl >/dev/null 2>&1; then
        timeout 10 openssl s_client -connect localhost:8443 -status </dev/null >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "OCSP cache warmed up successfully"
        else
            echo "OCSP warm-up connection completed (response may still be fetching)"
        fi
    else
        echo "OpenSSL not available for OCSP warm-up, skipping..."
    fi
}

# Start certificate monitor in background to automatically reload Nginx when the certificate changes
monitor_certs() {
    echo "Starting certificate monitor..."

    # Wait for certificate to appear (check every 60 seconds)
    # This handles first-time deployments where cert doesn't exist yet
    while [ ! -f "$CERT_PATH" ]; do
        echo "Waiting for certificate to be created: $CERT_PATH"
        sleep 60
    done

    echo "Certificate detected. Starting inotifywait monitoring: $CERT_PATH"

    # Monitor for certificate changes (renewals)
    while inotifywait -e close_write,moved_to "$CERT_PATH" 2>/dev/null; do
        echo "Certificate file changed. Regenerating config and reloading Nginx..."
        generate_nginx_conf
        # Test config before reload to prevent downtime from invalid config
        nginx -t 2>/dev/null && nginx -s reload && echo "Nginx reloaded successfully" || echo "ERROR: Nginx reload failed"
        # Re-warm OCSP cache after certificate change
        warmup_ocsp &
    done
}

# Generate initial Nginx configuration
generate_nginx_conf

# Start the certificate monitor in the background (only in production)
if [ "$ENVIRONMENT" = "production" ]; then
    monitor_certs &
    # Warm up OCSP cache after nginx starts (runs in background)
    warmup_ocsp &
fi

# Execute the CMD (nginx)
exec "$@"
