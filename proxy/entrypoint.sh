#!/bin/bash

set -e

# Determine the environment
if [ "$ENVIRONMENT" = "production" ]; then
    echo "Configuring Nginx for HTTPS"
    envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' < /etc/nginx/conf.d/nginx.conf.template.ssl > /etc/nginx/conf.d/default.conf
else
    echo "Configuring Nginx for HTTP"
    envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' < /etc/nginx/conf.d/nginx.conf.template.http > /etc/nginx/conf.d/default.conf
fi

# Start Nginx
nginx -g 'daemon off;'
