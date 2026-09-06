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

# Start certificate monitor in background to automatically reload Nginx when certificates change
monitor_certs() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting certificate monitor..."

    local current_hash=""
    local live_dir="/etc/letsencrypt/live/${SERVER_NAME}"
    local archive_dir="/etc/letsencrypt/archive/${SERVER_NAME}"

    get_cert_hash() {
        if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
            # -L follows symlinks so hash changes when cert is renewed in archive
            sha256sum -L "$CERT_PATH" 2>/dev/null | awk '{print $1}'
        fi
    }

    # Handle first-time deployment where certificates don't exist yet
    if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Waiting for initial certificates to appear: $CERT_PATH"
        while [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; do
            sleep 10
        done

        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Initial certificate detected! Generating HTTPS configuration and reloading Nginx..."
        generate_nginx_conf
        if nginx -t 2>/dev/null; then
            nginx -s reload && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Nginx successfully reloaded into HTTPS mode"
        else
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: Initial Nginx HTTPS configuration validation failed"
        fi
    fi

    current_hash=$(get_cert_hash)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Active certificate fingerprint: ${current_hash:0:16}..."

    # Continuous monitoring loop
    while true; do
        # Use inotifywait on directories with a 300s timeout fallback
        # Watching directories catches new archive certs and symlink replacements
        if command -v inotifywait >/dev/null 2>&1; then
            inotifywait -t 300 -q -e create,moved_to,close_write,delete,attrib \
                "$live_dir" "$archive_dir" "/etc/letsencrypt/live" 2>/dev/null || true
        else
            sleep 300
        fi

        # Compare certificate hash
        local new_hash
        new_hash=$(get_cert_hash)

        if [ -n "$new_hash" ] && [ "$new_hash" != "$current_hash" ]; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔄 Certificate change detected! (new fingerprint: ${new_hash:0:16}...)"
            generate_nginx_conf
            if nginx -t 2>/dev/null; then
                if nginx -s reload; then
                    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Nginx reloaded successfully with updated certificate"
                    current_hash="$new_hash"
                else
                    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: Nginx reload failed"
                fi
            else
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: Nginx configuration test failed; reload aborted"
            fi
        fi
    done
}

# Generate initial Nginx configuration
generate_nginx_conf

# Start the certificate monitor in the background (only in production)
if [ "$ENVIRONMENT" = "production" ]; then
    monitor_certs &
fi

# Execute the CMD (nginx)
exec "$@"
