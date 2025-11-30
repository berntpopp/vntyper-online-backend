# VNtyper Security Hardening Plan

**Date**: 2025-11-30
**Status**: Proposed
**Priority**: High
**Version**: 2.0

## Executive Summary

Security audit conducted using three industry-standard scanning tools revealed an already strong security posture with room for targeted improvements, including future-proofing against quantum computing threats.

| Scanner | Current Score | Target Score |
|---------|--------------|--------------|
| Mozilla Observatory | A+ (130/100) | 145/100 (maximum) |
| SSL Labs | A+ | Maintain A+ |
| ImmuniWeb | A | A+ |

---

## Table of Contents

1. [Current Security Scan Results](#current-security-scan-results)
2. [Improvement Plan](#improvement-plan)
   - [Priority 1: DNS CAA Record](#priority-1-dns-caa-record-infrastructure)
   - [Priority 2: OCSP Stapling Fix](#priority-2-ocsp-stapling-verification)
   - [Priority 3: Post-Quantum Cryptography](#priority-3-post-quantum-cryptography-future-proofing)
   - [Priority 4: CSP Optimization](#priority-4-csp-unsafe-inline-mitigation)
   - [Priority 5: HIPAA/NIST Compliance](#priority-5-hipaanist-cipher-compliance)
3. [Implementation Checklist](#implementation-checklist)
4. [References](#references)

---

## Current Security Scan Results

### 1. Mozilla Observatory (A+ - 130/100)
**Excellent score. Maximum achievable is 145/100.**

| Test | Result | Score | Notes |
|------|--------|-------|-------|
| Content Security Policy | ✅ Pass | +25 | `style-src 'unsafe-inline'` deducts 5 pts |
| Cookies | ✅ Pass | 0 | No cookies set |
| CORS | ✅ Pass | 0 | - |
| Redirection | ✅ Pass | +5 | HTTP → HTTPS redirect |
| Referrer Policy | ✅ Pass | +5 | strict-origin-when-cross-origin |
| HSTS | ✅ Pass | +15 | 2-year max-age with preload (bonus) |
| Subresource Integrity | ✅ Pass | +5 | SRI on external scripts |
| X-Content-Type-Options | ✅ Pass | +5 | nosniff |
| X-Frame-Options | ✅ Pass | +5 | SAMEORIGIN |

**Opportunity**: Remove `unsafe-inline` from style-src to gain ~5 additional points.

### 2. SSL Labs (A+)
**Excellent score. Infrastructure improvements recommended.**

| Category | Status | Notes |
|----------|--------|-------|
| Certificate | ✅ Valid | Let's Encrypt RSA 2048-bit |
| Protocol Support | ✅ TLS 1.2/1.3 only | Optimal |
| Key Exchange | ✅ Strong | ECDHE X25519/P-256/P-384 |
| Cipher Strength | ✅ Strong | Modern AEAD ciphers |
| DNS CAA | ⚠️ Missing | No CAA record |
| OCSP Stapling | ⚠️ Needs Fix | Configured but not responding |
| Post-Quantum | ⚠️ Not Enabled | No hybrid key exchange |

### 3. ImmuniWeb (A)
**Good score with compliance gaps.**

| Standard | Status | Gap |
|----------|--------|-----|
| PCI DSS 4.0 | ✅ Compliant | None |
| HIPAA | ⚠️ Partial | OCSP, CHACHA20 |
| NIST SP 800-52 | ⚠️ Partial | Same as HIPAA |

---

## Improvement Plan

### Priority 1: DNS CAA Record (Infrastructure)

**Impact**: Prevents unauthorized certificate issuance
**Effort**: Low (DNS change only)
**Risk**: None

DNS CAA records specify which Certificate Authorities can issue certificates for your domain. This prevents attackers from obtaining fraudulent certificates.

**Action Required (DNS Provider):**
```dns
; Add to vntyper.org DNS zone
vntyper.org.    IN  CAA  0 issue "letsencrypt.org"
vntyper.org.    IN  CAA  0 issuewild "letsencrypt.org"
vntyper.org.    IN  CAA  0 iodef "mailto:security@vntyper.org"
```

**Verification:**
```bash
dig vntyper.org CAA +short
# Expected: 0 issue "letsencrypt.org"
```

---

### Priority 2: OCSP Stapling Verification

**Impact**: Faster TLS handshakes, improved privacy
**Effort**: Low
**Risk**: Low (graceful fallback)

OCSP stapling allows the server to provide certificate revocation status, eliminating the need for clients to contact the CA directly.

**Current Issue**: OCSP stapling is configured but returning no response.

**Root Cause Analysis:**
1. Missing `ssl_trusted_certificate` directive
2. Resolver may be blocked or timing out
3. OCSP cache not warmed on startup

**Fix (proxy/nginx.conf.template.ssl):**

```nginx
# After ssl_certificate_key (line 22), add:
ssl_trusted_certificate /etc/letsencrypt/live/${SERVER_NAME}/chain.pem;

# Update resolver (line 34) - add Cloudflare DNS:
resolver 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 10s;
```

**Warm-up Script (proxy/entrypoint.sh):**
```bash
# Add after nginx starts (background process):
(sleep 10 && openssl s_client -connect localhost:443 -status < /dev/null 2>/dev/null) &
```

**Verification:**
```bash
echo | openssl s_client -connect vntyper.org:443 -status 2>/dev/null | grep "OCSP Response Status"
# Expected: OCSP Response Status: successful (0x0)
```

---

### Priority 3: Post-Quantum Cryptography (Future-Proofing)

**Impact**: Protection against "harvest now, decrypt later" quantum attacks
**Effort**: High (requires OpenSSL 3.5+)
**Risk**: Medium (browser compatibility)
**Timeline**: 6-12 months

#### The Quantum Threat

Quantum computers capable of breaking RSA and ECC are estimated to arrive between 2030-2040. However, adversaries may be capturing encrypted traffic now to decrypt later once quantum computers become available ("harvest now, decrypt later" attack). For medical/genetic data like VNtyper handles, this is a significant concern.

#### NIST Post-Quantum Standards (August 2024)

NIST released finalized standards:
- **ML-KEM** (FIPS 203) - Key encapsulation, replaces RSA/ECDH for key exchange
- **ML-DSA** (FIPS 204) - Digital signatures, replaces RSA/ECDSA
- **SLH-DSA** (FIPS 205) - Stateless hash-based signatures (backup)

#### Current Browser Support (As of Nov 2025)

| Browser | Hybrid PQ Support | Notes |
|---------|------------------|-------|
| Chrome 124+ | ✅ Default | X25519+ML-KEM-768 |
| Edge 124+ | ✅ Default | Same as Chrome |
| Firefox 124+ | ⚠️ Flag | `security.tls.enable_kyber` |
| Safari | ❌ Not yet | Expected 2025 |

Cloudflare reports ~38% of HTTPS traffic now uses hybrid PQ handshakes.

#### Implementation Options

**Option A: Immediate (OpenSSL 3.0 + OQS Provider)**

Uses [Open Quantum Safe](https://openquantumsafe.org/) provider with existing OpenSSL.

1. Build nginx with OQS provider:
```dockerfile
# In proxy Dockerfile
RUN apt-get install -y cmake ninja-build
RUN git clone https://github.com/open-quantum-safe/oqs-provider.git && \
    cd oqs-provider && mkdir build && cd build && \
    cmake -GNinja .. && ninja && ninja install
```

2. Configure nginx:
```nginx
ssl_ecdh_curve x25519_kyber768:p384_kyber768:x25519:secp384r1:secp256r1;
```

**Option B: Future (OpenSSL 3.5+)**

OpenSSL 3.5.0 (released April 2025) includes native ML-KEM support.

1. Update base image to use OpenSSL 3.5
2. Rebuild nginx against OpenSSL 3.5
3. Configure hybrid curves:
```nginx
ssl_ecdh_curve X25519MLKEM768:SecP384r1MLKEM1024:x25519:secp384r1;
```

**Recommended Approach:**

Given VNtyper handles sensitive genetic data:

| Phase | Timeline | Action |
|-------|----------|--------|
| Phase 1 | Now | Monitor browser adoption |
| Phase 2 | Q1 2026 | Implement OQS provider on staging |
| Phase 3 | Q2 2026 | Production rollout with hybrid PQ |
| Phase 4 | 2027+ | Full PQ-only migration |

**Testing PQ Support:**
```bash
# With OpenSSL 3.5+
openssl s_client -groups X25519MLKEM768 -connect vntyper.org:443

# Check negotiated key exchange
echo | openssl s_client -connect vntyper.org:443 2>&1 | grep "Server Temp Key"
```

#### Key Size Considerations

| Algorithm | Public Key | Private Key | Ciphertext |
|-----------|------------|-------------|------------|
| X25519 | 32 bytes | 32 bytes | 32 bytes |
| ML-KEM-768 | 1,184 bytes | 2,400 bytes | 1,088 bytes |
| Hybrid | 1,216 bytes | 2,432 bytes | 1,120 bytes |

TLS handshake size increases ~3KB with hybrid PQ. Performance impact is minimal (~2.3x X25519).

---

### Priority 4: CSP `unsafe-inline` Mitigation

**Impact**: Eliminates XSS attack vector, +5 points on Observatory
**Effort**: High (frontend refactoring)
**Risk**: Medium (may break functionality)

#### Current CSP Analysis

```
style-src 'self' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net 'unsafe-inline'
```

`unsafe-inline` is required because the frontend uses:
- Dynamic `element.style.property = value` assignments
- Inline style attributes in JavaScript-generated HTML
- Third-party libraries that inject inline styles

#### Removal Strategy (OWASP Best Practices)

**Phase 1: Audit (1 week)**
1. Enable CSP report-only mode to identify violations
2. Catalog all inline style sources
3. Document third-party library requirements

```nginx
# Add alongside existing CSP header
add_header Content-Security-Policy-Report-Only "default-src 'none'; style-src 'self' https://cdnjs.cloudflare.com; report-uri /api/csp-report/" always;
```

**Phase 2: Refactor (2-4 weeks)**

Replace inline styles with CSS classes:
```javascript
// Before
element.style.display = 'none';
element.style.backgroundColor = '#ff0000';

// After
element.classList.add('hidden');
element.classList.add('error-bg');
```

```css
/* styles.css */
.hidden { display: none; }
.error-bg { background-color: #ff0000; }
```

**Phase 3: Nonce Implementation (Complex)**

For unavoidable inline styles, implement nonces:

```nginx
# nginx.conf - Generate nonce per request
set $csp_nonce $request_id;
sub_filter_once off;
sub_filter '</head>' '<meta name="csp-nonce" content="$csp_nonce"></head>';

add_header Content-Security-Policy "style-src 'self' 'nonce-$csp_nonce'" always;
```

```javascript
// Frontend - Read nonce and apply to dynamic styles
const nonce = document.querySelector('meta[name="csp-nonce"]')?.content;
const style = document.createElement('style');
style.nonce = nonce;
style.textContent = '.dynamic { color: red; }';
document.head.appendChild(style);
```

**Phase 4: Hash-Based Fallback**

For completely static inline styles, use hashes:
```bash
# Generate hash for inline style content
echo -n '.static { margin: 0; }' | openssl sha256 -binary | base64
# Output: abc123...
```

```nginx
add_header Content-Security-Policy "style-src 'self' 'sha256-abc123...'" always;
```

#### Recommended Timeline

| Week | Task | Risk |
|------|------|------|
| 1 | Enable report-only, collect violations | None |
| 2-3 | Refactor inline styles to CSS classes | Low |
| 4 | Test with `unsafe-inline` removed | Medium |
| 5 | Deploy nonce system if needed | Medium |
| 6 | Production release | Low |

---

### Priority 5: HIPAA/NIST Cipher Compliance (Optional)

**Impact**: Full HIPAA/NIST compliance certification
**Effort**: Low
**Risk**: Low

#### CHACHA20 Cipher Debate

ImmuniWeb flags CHACHA20-POLY1305 as non-HIPAA/NIST compliant because:
- NIST SP 800-52 Rev. 2 doesn't explicitly list CHACHA20
- HIPAA references NIST guidelines

However:
- CHACHA20 is cryptographically secure (used by Google, CloudFlare)
- Faster than AES on devices without AES-NI hardware
- Mozilla modern profile recommends it
- NIST is evaluating for future inclusion

#### Options

**Option A: Strict HIPAA Compliance**
Remove CHACHA20 ciphers:
```nginx
ssl_ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256";
```

**Option B: Keep CHACHA20 (Recommended)**
Current config is secure. Document risk acceptance for compliance audit.

**Recommendation**: Keep CHACHA20 unless undergoing formal HIPAA certification.

---

## Implementation Checklist

### Immediate (Week 1)

- [ ] Add DNS CAA record via DNS provider
- [ ] Add `ssl_trusted_certificate` to nginx config
- [ ] Add Cloudflare DNS to resolver list
- [ ] Add OCSP warm-up to entrypoint
- [ ] Test OCSP stapling response
- [ ] Re-run SSL Labs scan

### Short-term (Weeks 2-4)

- [ ] Enable CSP report-only header
- [ ] Collect CSP violation reports
- [ ] Begin frontend inline style audit
- [ ] Test with `unsafe-inline` removed in staging

### Medium-term (Months 1-3)

- [ ] Complete frontend CSP refactoring
- [ ] Deploy nonce-based CSP if needed
- [ ] Remove `unsafe-inline` in production
- [ ] Re-run Mozilla Observatory scan

### Long-term (6-12 months)

- [ ] Evaluate OpenSSL 3.5 availability in base images
- [ ] Test OQS provider on staging
- [ ] Implement hybrid PQ key exchange
- [ ] Monitor quantum computing developments

---

## Proposed Nginx Configuration Changes

```nginx
# ============================================
# IMMEDIATE CHANGES (proxy/nginx.conf.template.ssl)
# ============================================

# Line 22 - After ssl_certificate_key, add:
ssl_trusted_certificate /etc/letsencrypt/live/${SERVER_NAME}/chain.pem;

# Line 34 - Update resolver:
resolver 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 10s;

# ============================================
# FUTURE CHANGES (Post-Quantum, OpenSSL 3.5+)
# ============================================

# Replace ssl_ecdh_curve line with:
ssl_ecdh_curve X25519MLKEM768:SecP384r1MLKEM1024:x25519:secp384r1;

# ============================================
# FUTURE CHANGES (CSP without unsafe-inline)
# ============================================

# Replace CSP header with nonce-based version:
set $csp_nonce $request_id;
add_header Content-Security-Policy "default-src 'none'; script-src 'self' https://biowasm.com https://cdnjs.cloudflare.com https://cdn.jsdelivr.net 'sha256-1I8qOd6RIfaPInCv8Ivv4j+J0C6d7I8+th40S5U/TVc=' 'wasm-unsafe-eval'; style-src 'self' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net 'nonce-$csp_nonce'; img-src 'self' https://fastapi.tiangolo.com data:; object-src 'none'; frame-ancestors 'self'; base-uri 'self'; form-action 'self'; worker-src 'self' blob:; connect-src 'self' https://biowasm.com https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; manifest-src 'self';" always;
```

---

## Testing Commands

```bash
# Test OCSP stapling
echo | openssl s_client -connect vntyper.org:443 -status 2>/dev/null | grep -A 5 "OCSP"

# Test DNS CAA
dig vntyper.org CAA +short

# Test TLS configuration
nmap --script ssl-enum-ciphers -p 443 vntyper.org

# Test CSP header
curl -sI https://vntyper.org | grep -i content-security

# Test post-quantum (when implemented)
openssl s_client -groups X25519MLKEM768 -connect vntyper.org:443

# Full security scan
docker run --rm securityheaders/securityheaders https://vntyper.org
```

---

## Risk Assessment

| Change | Risk | Impact | Mitigation |
|--------|------|--------|------------|
| DNS CAA | None | None | DNS-only, no service impact |
| OCSP fix | Low | None | Graceful fallback if misconfigured |
| Post-Quantum | Medium | Medium | Phase rollout, browser testing |
| CSP refactor | Medium | High | Extensive testing, report-only first |
| CHACHA20 removal | Low | Low | Test with target browsers |

---

## References

### Standards & Guidelines
- [NIST FIPS 203 - ML-KEM](https://csrc.nist.gov/pubs/fips/203/final)
- [NIST FIPS 204 - ML-DSA](https://csrc.nist.gov/pubs/fips/204/final)
- [NIST SP 800-52 Rev. 2 - TLS Guidelines](https://csrc.nist.gov/publications/detail/sp/800-52/rev-2/final)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [OWASP CSP Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)

### Tools & Scanners
- [Mozilla Observatory](https://developer.mozilla.org/en-US/observatory/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)
- [ImmuniWeb SSL Test](https://www.immuniweb.com/ssl/)
- [Mozilla SSL Config Generator](https://ssl-config.mozilla.org/)

### Post-Quantum Resources
- [Open Quantum Safe Project](https://openquantumsafe.org/)
- [OpenSSL 3.5 PQ Support](https://www.openssl.org/blog/blog/2025/04/08/openssl3.5.0/)
- [Post-Quantum TLS with Nginx Guide](https://www.linode.com/docs/guides/post-quantum-encryption-nginx-ubuntu2404/)
- [IETF Hybrid Key Exchange Draft](https://datatracker.ietf.org/doc/draft-ietf-tls-hybrid-design/)
- [Cloudflare PQ Statistics](https://blog.cloudflare.com/post-quantum-for-all/)

### CSP Resources
- [Google Strict CSP](https://csp.withgoogle.com/docs/strict-csp.html)
- [MDN Content-Security-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy)
- [CSP Hash Generator](https://report-uri.com/home/hash)

---

## Appendix A: Post-Quantum Algorithm Comparison

| Algorithm | Type | Security Level | Key Size | Performance |
|-----------|------|----------------|----------|-------------|
| RSA-2048 | Classical | 112-bit | 2048 bit | Slow |
| ECDH X25519 | Classical | 128-bit | 256 bit | Fast |
| ML-KEM-512 | Post-Quantum | 128-bit (PQ) | 800 byte | Fast |
| ML-KEM-768 | Post-Quantum | 192-bit (PQ) | 1,184 byte | Fast |
| ML-KEM-1024 | Post-Quantum | 256-bit (PQ) | 1,568 byte | Moderate |
| X25519+ML-KEM-768 | Hybrid | 128+192 bit | ~1,440 byte | Fast |

## Appendix B: Mozilla Observatory Scoring Breakdown

| Category | Max Points | Current | After Improvements |
|----------|------------|---------|-------------------|
| CSP | 25 | 20 | 25 |
| Cookies | 5 | 5 | 5 |
| CORS | 0 | 0 | 0 |
| Redirection | 5 | 5 | 5 |
| Referrer-Policy | 5 | 5 | 5 |
| HSTS | 15 | 15 | 15 |
| SRI | 5 | 5 | 5 |
| X-Content-Type-Options | 5 | 5 | 5 |
| X-Frame-Options | 5 | 5 | 5 |
| **Bonus** | +75 | +65 | +75 |
| **Total** | 145 | 130 | 145 |
