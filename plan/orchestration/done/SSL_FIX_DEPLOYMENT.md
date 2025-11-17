# SSL Certificate Auto-Renewal Fix - VPS Deployment Guide

**Date**: 2025-10-24
**Status**: ✅ Ready for VPS deployment
**Issue**: [GitHub #25](https://github.com/berntpopp/vntyper-online-backend/issues/25)

---

## Summary

Fixed SSL certificate auto-renewal system. **Root cause**: certbot's `--deploy-hook 'nginx -s reload'` cannot execute across Docker container boundaries.

**Solution**: Event-driven architecture using shared volumes and inotifywait monitoring.

---

## Files Modified

### certbot/entrypoint.sh
- Complete rewrite (170 lines)
- Continuous 12-hour renewal loop (replaces cron)
- Removed broken `--deploy-hook`
- Added SIGTERM trap for graceful shutdown

### proxy/entrypoint.sh
- Enhanced (52 lines)
- Certificate wait loop (fixes first-time deployment)
- inotifywait monitoring with auto-reload
- `nginx -t` safety check before reload

### CLAUDE.md
- Added SSL Certificate Management section (line 341)
- Contains ongoing operational documentation

---

## VPS Deployment

### Option 1: Staging First (Recommended)

Test with Let's Encrypt staging to avoid rate limits:

```bash
# 1. Connect and pull latest code
ssh user@vntyper.org
cd /path/to/vntyper-online-backend
git pull origin main

# 2. Enable staging mode
sed -i 's/CERTBOT_STAGING=0/CERTBOT_STAGING=1/' .env.production

# 3. Build and deploy
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  build certbot

docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  up -d certbot proxy

# 4. Monitor logs (expect cert acquired in ~60 seconds)
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  logs -f certbot proxy

# Look for:
# certbot: "Certificate acquired successfully"
# proxy: "Certificate detected. Starting inotifywait monitoring"

# 5. Validate staging cert
docker exec vntyper_certbot openssl x509 -issuer -noout \
  -in /etc/letsencrypt/live/vntyper.org/fullchain.pem
# Expected: issuer=CN = (STAGING) Artificial Apricot R3

# 6. Test force renewal (verify auto-reload works)
docker exec vntyper_certbot certbot renew --force-renewal \
  --webroot -w /var/www/certbot

# Check for auto-reload
docker-compose logs proxy | grep "Nginx reloaded successfully"

# 7. Switch to production mode
sed -i 's/CERTBOT_STAGING=1/CERTBOT_STAGING=0/' .env.production

# 8. Remove staging certificates
docker exec vntyper_certbot rm -rf /etc/letsencrypt/live/vntyper.org
docker exec vntyper_certbot rm -rf /etc/letsencrypt/archive/vntyper.org
docker exec vntyper_certbot rm -rf /etc/letsencrypt/renewal/vntyper.org.conf

# 9. Restart for production cert
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  restart certbot

# 10. Monitor production cert acquisition
docker-compose logs -f certbot
# Expected: "Certificate acquired successfully" in ~30 seconds

# 11. Validate production cert
docker exec vntyper_certbot openssl x509 -issuer -noout \
  -in /etc/letsencrypt/live/vntyper.org/fullchain.pem
# Expected: issuer=C = US, O = Let's Encrypt, CN = R3

# 12. Test HTTPS
curl -I https://vntyper.org
# Expected: HTTP/2 200
```

### Option 2: Direct Production (If Confident)

```bash
# 1-3: Same as above (connect, pull, build)

# 4. Ensure production mode
grep CERTBOT_STAGING .env.production
# Should show: CERTBOT_STAGING=0

# 5. Deploy
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  up -d certbot proxy

# 6. Monitor
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  logs -f certbot proxy

# 7. Validate cert
docker exec vntyper_certbot openssl x509 -issuer -noout \
  -in /etc/letsencrypt/live/vntyper.org/fullchain.pem

# 8. Test HTTPS
curl -I https://vntyper.org
```

---

## Post-Deployment Monitoring

### First Hour
```bash
# Containers running
docker ps | grep -E 'certbot|proxy'

# Monitoring active
docker logs vntyper_proxy | grep "Starting inotifywait monitoring"

# No critical errors
docker-compose logs certbot proxy | grep -i error
```

### First 24 Hours
```bash
# Renewal checks (2 per day)
docker logs vntyper_certbot | grep "Renewal Check #"

# Certificate expiration
docker exec vntyper_certbot openssl x509 -enddate -noout \
  -in /etc/letsencrypt/live/vntyper.org/fullchain.pem
# Should show ~90 days from today
```

### After 60 Days (Renewal Window)
```bash
# Auto-renewal happened
docker logs vntyper_certbot | grep "Certificate was recently renewed"

# Auto-reload happened
docker logs vntyper_proxy | grep "Nginx reloaded successfully"
```

---

## Rollback Procedure

If deployment fails, rollback to old entrypoint scripts:

```bash
# 1. Stop services
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  stop certbot proxy

# 2. Restore old scripts (if you have backups)
# Note: Backup files were in certbot/ and proxy/ directories
# You'll need to restore from git history if backups were deleted

git checkout HEAD~1 -- certbot/entrypoint.sh
git checkout HEAD~1 -- proxy/entrypoint.sh

# 3. Rebuild
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  build certbot

# 4. Restart
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  up -d certbot proxy

# 5. Verify
curl -I https://vntyper.org
```

---

## Success Criteria

**Immediate (First Hour)**:
- ✓ Certbot and proxy containers running
- ✓ Certificate acquired (fresh deployment) or detected (existing)
- ✓ inotifywait monitoring active
- ✓ HTTPS accessible

**7 Days**:
- ✓ Zero container restarts
- ✓ 14 renewal checks completed (2/day)
- ✓ No renewal failures

**90 Days**:
- ✓ Certificate auto-renewed around day 60
- ✓ Nginx auto-reloaded
- ✓ Zero manual interventions

---

## Troubleshooting

For operational issues after deployment, see **CLAUDE.md line 341** (SSL Certificate Management section):
- Monitoring renewal
- Certificate not renewing
- Initial acquisition fails
- Nginx not picking up new cert
- Container keeps restarting
- Manual intervention procedures

---

## Technical Details

**What changed**:
- Certbot: Cron → Continuous 12-hour loop
- Proxy: Added certificate wait loop + inotifywait monitoring
- Communication: Deploy-hook → File system events (shared volumes)

**First-time deployment timeline**:
- T+0s: Proxy starts, waits for cert (60s polling)
- T+15s: Certbot starts (15s delay)
- T+30s: Certificate created
- T+60s: Proxy detects cert, starts monitoring
- **Result**: Fully automatic, zero manual intervention

**Renewal timeline**:
- Every 12 hours: Certbot checks if renewal needed (<30 days)
- On renewal: New cert written to shared volume
- inotifywait detects change, runs `nginx -t && nginx -s reload`
- **Result**: Zero downtime, automatic reload

---

**Estimated deployment time**: 15-20 minutes
**Estimated downtime**: 0 seconds
**Manual steps required**: 0 (after running commands above)

---

For questions or issues, check:
1. This deployment guide (one-time setup)
2. CLAUDE.md line 341 (ongoing operations)
3. GitHub Issue #25 (background/discussion)
