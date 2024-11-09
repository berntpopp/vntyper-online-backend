#!/bin/sh

set -e

echo "Starting Certbot with the following parameters:"
echo "SERVER_NAME: $SERVER_NAME"
echo "CERTBOT_EMAIL: $CERTBOT_EMAIL"
echo "CERTBOT_STAGING: $CERTBOT_STAGING"

# Determine if we should use the staging environment
if [ "$CERTBOT_STAGING" = "1" ]; then
    STAGING_ARG="--staging"
else
    STAGING_ARG=""
fi

# Run Certbot to obtain certificates
certbot certonly --webroot -w /var/www/certbot \
    -d "$SERVER_NAME" \
    -d "$SERVER_NAME_SUBDOMAIN" \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --non-interactive \
    $STAGING_ARG

# Add cron job for renewal
echo "0 0 * * * certbot renew --webroot -w /var/www/certbot --quiet && nginx -s reload" >> /etc/crontabs/root

# Start cron daemon
crond -f
