#!/bin/sh
# certbot/entrypoint.sh
# This script handles obtaining and renewing SSL certificates using Certbot.
# It first checks if a certificate file exists and validates its expiration.
# If the certificate is absent or expires within 30 days, a new certificate is requested or renewed.
# A cron job is then scheduled for regular certificate renewal.

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

# Define certificate file path
CERT_FILE="/etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem"
# Define the minimum validity period (30 days in seconds)
MIN_VALIDITY=$((30 * 24 * 3600))

# Check if certificate file exists and validate its expiration
if [ -f "$CERT_FILE" ]; then
    echo "Certificate file found at $CERT_FILE. Checking expiration..."
    if openssl x509 -checkend "$MIN_VALIDITY" -noout -in "$CERT_FILE"; then
        echo "Certificate is valid for at least 30 more days."
    else
        echo "Certificate will expire in less than 30 days. Requesting renewal..."
        certbot certonly --webroot -w /var/www/certbot \
            -d "$SERVER_NAME" \
            -d "$SERVER_NAME_SUBDOMAIN" \
            --email "$CERTBOT_EMAIL" \
            --agree-tos \
            --non-interactive \
            $STAGING_ARG
    fi
else
    echo "No certificate file found for $SERVER_NAME. Requesting new certificate..."
    certbot certonly --webroot -w /var/www/certbot \
        -d "$SERVER_NAME" \
        -d "$SERVER_NAME_SUBDOMAIN" \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --non-interactive \
        $STAGING_ARG
fi

# Attempt immediate renewal (certbot will only renew if needed)
echo "Attempting immediate certificate renewal if due..."
certbot renew --webroot -w /var/www/certbot --quiet --deploy-hook 'nginx -s reload'

# Add cron job for automated renewal if not already present
CRON_JOB="0 0 * * * certbot renew --webroot -w /var/www/certbot --quiet --deploy-hook 'nginx -s reload'"
if ! crontab -l | grep -Fq "$CRON_JOB"; then
    echo "$CRON_JOB" >> /etc/crontabs/root
fi

# Start cron daemon in the foreground.
crond -f
