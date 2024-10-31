#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Replace environment variables in the Nginx template and output to the actual config
envsubst '${SERVER_NAME} ${CLIENT_MAX_BODY_SIZE}' < /etc/nginx/conf.d/nginx.conf.template > /etc/nginx/conf.d/default.conf

# Start Nginx
nginx -g 'daemon off;'
