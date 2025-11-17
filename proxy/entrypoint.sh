#!/bin/bash

set -e

CERT_PATH="/etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/${SERVER_NAME}/privkey.pem"

# Function to generate Nginx configuration
generate_nginx_conf() {
    if [ "$ENVIRONMENT" = "production" ]; then
        if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
            echo "SSL certificates found. Configuring Nginx for HTTPS."
            envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' \
                < /etc/nginx/conf.d/nginx.conf.template.ssl > /etc/nginx/conf.d/default.conf
        else
            echo "SSL certificates not found. Configuring Nginx for ACME challenge."
            envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' \
                < /etc/nginx/conf.d/nginx.conf.template.acme > /etc/nginx/conf.d/default.conf
        fi
    else
        echo "Configuring Nginx for HTTP (development)."
        envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' \
            < /etc/nginx/conf.d/nginx.conf.template.http > /etc/nginx/conf.d/default.conf
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
        echo "Certificate file changed. Reloading Nginx..."
        # Test config before reload to prevent downtime from invalid config
        nginx -t 2>/dev/null && nginx -s reload && echo "Nginx reloaded successfully" || echo "ERROR: Nginx reload failed"
    done
}

# Generate Nginx configuration
generate_nginx_conf

# Start the certificate monitor in the background
monitor_certs &

# Start Nginx in the foreground
nginx -g 'daemon off;'
