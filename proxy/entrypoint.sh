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

# Generate Nginx configuration
generate_nginx_conf

# Start Nginx
nginx -g 'daemon off;'
