#!/bin/sh
# certbot/entrypoint.sh

set -e

echo "Starting Certbot with the following parameters:"
echo "SERVER_NAME: $SERVER_NAME"
echo "SERVER_NAME_SUBDOMAIN: $SERVER_NAME_SUBDOMAIN"
echo "CERTBOT_EMAIL: $CERTBOT_EMAIL"
echo "CERTBOT_STAGING: $CERTBOT_STAGING"

# Determine if we should use the staging environment
if [ "$CERTBOT_STAGING" = "1" ]; then
    STAGING_ARG="--staging"
else
    STAGING_ARG=""
fi

# Check if certificates are already valid
if certbot certificates | grep -q "VALID"; then
    echo "Certificates are still valid. Skipping issuance."
else
    echo "No valid certificates found. Requesting new certificates..."
    certbot certonly --webroot -w /var/www/certbot \
        -d "$SERVER_NAME" \
        -d "$SERVER_NAME_SUBDOMAIN" \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --non-interactive \
        $STAGING_ARG
fi

# Add cron job for automated renewal
echo "0 0 * * * certbot renew --webroot -w /var/www/certbot --quiet --deploy-hook 'nginx -s reload'" >> /etc/crontabs/root

# Start cron daemon
crond -f
