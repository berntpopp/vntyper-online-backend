#!/bin/sh
# certbot/entrypoint.sh
# Handles SSL certificate acquisition and renewal using Certbot in a continuous loop.
# The proxy container monitors certificate changes via inotifywait and reloads nginx automatically.
# This approach respects container boundaries and eliminates cross-container dependencies.

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

echo "========================================="
echo "Certbot SSL Certificate Manager"
echo "========================================="
echo "SERVER_NAME:            $SERVER_NAME"
echo "SERVER_NAME_SUBDOMAIN:  $SERVER_NAME_SUBDOMAIN"
echo "CERTBOT_EMAIL:          $CERTBOT_EMAIL"
echo "CERTBOT_STAGING:        $CERTBOT_STAGING"
echo "========================================="

# Determine staging flag
if [ "$CERTBOT_STAGING" = "1" ]; then
    STAGING_ARG="--staging"
    echo "⚠️  STAGING MODE ENABLED - Using Let's Encrypt staging servers"
else
    STAGING_ARG=""
    echo "✓ PRODUCTION MODE - Using Let's Encrypt production servers"
fi

# Certificate paths
CERT_FILE="/etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem"
MIN_VALIDITY_DAYS=30
MIN_VALIDITY_SECONDS=$((MIN_VALIDITY_DAYS * 24 * 3600))

# Renewal interval (12 hours = 43200 seconds)
# Certbot official docs recommend running twice daily (0 0,12 * * *)
RENEWAL_INTERVAL=43200

# ============================================================================
# STARTUP DELAY - Fix race condition with proxy container
# ============================================================================

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Waiting 15 seconds for proxy container to initialize..."
sleep 15
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Proceeding with certificate check"

# ============================================================================
# INITIAL CERTIFICATE ACQUISITION
# ============================================================================

echo ""
echo "========================================="
echo "Initial Certificate Check"
echo "========================================="

if [ -f "$CERT_FILE" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Certificate file found: $CERT_FILE"

    # Validate certificate expiration
    if openssl x509 -checkend "$MIN_VALIDITY_SECONDS" -noout -in "$CERT_FILE" 2>/dev/null; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Certificate valid for at least $MIN_VALIDITY_DAYS days"

        # Display expiration info
        EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Certificate expires: $EXPIRY_DATE"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  Certificate expires in less than $MIN_VALIDITY_DAYS days"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Requesting renewal..."

        # Attempt renewal
        if certbot certonly --webroot -w /var/www/certbot \
            -d "$SERVER_NAME" \
            -d "$SERVER_NAME_SUBDOMAIN" \
            --email "$CERTBOT_EMAIL" \
            --agree-tos \
            --non-interactive \
            --keep-until-expiring \
            $STAGING_ARG; then
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Certificate renewed successfully"
        else
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: Certificate renewal failed (exit code $?)"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Will retry in renewal loop..."
        fi
    fi
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] No certificate found. Requesting new certificate..."

    # Request new certificate
    if certbot certonly --webroot -w /var/www/certbot \
        -d "$SERVER_NAME" \
        -d "$SERVER_NAME_SUBDOMAIN" \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --non-interactive \
        $STAGING_ARG; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Certificate acquired successfully"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  Proxy container will auto-reload nginx via inotifywait"
    else
        EXIT_CODE=$?
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: Certificate acquisition failed (exit code $EXIT_CODE)"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Common causes:"
        echo "  - DNS not pointing to this server"
        echo "  - Port 80 not accessible from internet"
        echo "  - Rate limiting (5 failed validations/hour, 50 certs/week per registered domain)"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Will retry in renewal loop..."
    fi
fi

# ============================================================================
# CONTINUOUS RENEWAL LOOP
# ============================================================================

echo ""
echo "========================================="
echo "Starting Continuous Renewal Loop"
echo "========================================="
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Renewal checks every 12 hours"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Certbot only renews if <30 days until expiry"
echo ""

# Trap SIGTERM for graceful shutdown
trap 'echo "[$(date +"%Y-%m-%d %H:%M:%S")] Received SIGTERM, shutting down gracefully..."; exit 0' TERM

ITERATION=0

while true; do
    ITERATION=$((ITERATION + 1))

    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================="
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Renewal Check #$ITERATION"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================="

    # Run certbot renew
    # Exit codes: 0 = success or no renewal needed, 1 = renewal failed
    if certbot renew --webroot -w /var/www/certbot --quiet; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Renewal check completed successfully"

        # Check if certificate was actually renewed (modification time check)
        if [ -f "$CERT_FILE" ]; then
            # Get certificate modification time
            # -c %Y for Linux (GNU/BusyBox), -f %m for BSD/macOS (fallback)
            CERT_AGE=$(stat -c %Y "$CERT_FILE" 2>/dev/null || stat -f %m "$CERT_FILE" 2>/dev/null)
            CURRENT_TIME=$(date +%s)
            SECONDS_SINCE_MODIFIED=$((CURRENT_TIME - CERT_AGE))

            if [ $SECONDS_SINCE_MODIFIED -lt $RENEWAL_INTERVAL ]; then
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Certificate was recently renewed"
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  Proxy container will detect change and reload nginx"
            else
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  No renewal performed (certificate not yet due)"
            fi
        fi
    else
        EXIT_CODE=$?
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: Renewal check failed (exit code $EXIT_CODE)"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Check logs above for details"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Will retry at next interval"
    fi

    # Display next check time (simplified - no complex date math)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Next check in 12 hours"
    echo ""

    # Sleep for 12 hours (using background sleep + wait for proper signal handling)
    sleep $RENEWAL_INTERVAL &
    wait $!
done
