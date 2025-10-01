# API & Networking Improvements

**Priority:** 🟡 **MEDIUM**
**Effort:** 3-4 days
**Status:** Open

---

## Executive Summary

API networking lacks **retry logic**, **timeout handling**, **request cancellation**, and has **duplicate error parsing code**. Network failures cause immediate failures with no recovery.

**Key Issues:**
- No retry with exponential backoff
- No request timeouts (hangs forever on slow networks)
- No AbortController for cancellation
- Duplicate error parsing in 8 locations
- No request queueing or deduplication

---

## Current Issues

### 1. No Retry Logic

```javascript
// apiInteractions.js:47-50
const response = await fetch(`${window.CONFIG.API_URL}/run-job/`, {
    method: 'POST',
    body: formData,
});
// ⚠️ One attempt only, immediate failure on network hiccup
```

**Should retry** transient failures (network errors, 5xx responses).

### 2. No Timeout Handling

```javascript
// Current: No timeout, hangs forever
const response = await fetch(url);

// Should have:
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 30000);
const response = await fetch(url, { signal: controller.signal });
```

### 3. Duplicate Error Parsing (8 locations)

**Same pattern repeated:**

```javascript
// apiInteractions.js:52-69
if (!response.ok) {
    let errorMessage = 'Failed to submit job(s).';
    try {
        const errorData = await response.json();
        if (errorData.detail) {
            if (Array.isArray(errorData.detail)) {
                errorMessage = errorData.detail.map(err => err.msg).join(', ');
            } else if (typeof errorData.detail === 'string') {
                errorMessage = errorData.detail;
            }
        }
    } catch (e) {
        logMessage('Error parsing error response', 'error');
    }
    throw new Error(errorMessage);
}
```

**Repeated in:**
- submitJobToAPI (lines 52-69)
- getJobStatus (lines 97-112)
- getCohortStatus (lines 165-178)
- createCohort (similar pattern)
- + 4 more locations

---

## Proposed Solution

### 1. Create Centralized HTTP Client

```javascript
// services/httpClient.js

export class HTTPClient {
    constructor(baseURL, options = {}) {
        this.baseURL = baseURL;
        this.defaultTimeout = options.timeout || 30000;
        this.maxRetries = options.maxRetries || 3;
        this.retryDelay = options.retryDelay || 1000;
    }

    /**
     * Fetch with timeout
     */
    async fetchWithTimeout(url, options = {}) {
        const controller = new AbortController();
        const timeout = options.timeout || this.defaultTimeout;

        const timeoutId = setTimeout(() => controller.abort(), timeout);

        try {
            const response = await fetch(url, {
                ...options,
                signal: controller.signal
            });
            return response;
        } finally {
            clearTimeout(timeoutId);
        }
    }

    /**
     * Retry with exponential backoff
     */
    async retryWithBackoff(fn, retries = this.maxRetries) {
        let lastError;

        for (let attempt = 0; attempt <= retries; attempt++) {
            try {
                return await fn();
            } catch (error) {
                lastError = error;

                // Don't retry on client errors (4xx)
                if (error.status >= 400 && error.status < 500) {
                    throw error;
                }

                if (attempt < retries) {
                    const delay = this.retryDelay * Math.pow(2, attempt);
                    await new Promise(resolve => setTimeout(resolve, delay));
                }
            }
        }

        throw lastError;
    }

    /**
     * Parse error response
     */
    async parseError(response) {
        let errorMessage = `Request failed with status ${response.status}`;

        try {
            const data = await response.json();
            if (data.detail) {
                if (Array.isArray(data.detail)) {
                    errorMessage = data.detail.map(err => err.msg).join(', ');
                } else {
                    errorMessage = data.detail;
                }
            }
        } catch (e) {
            // Response not JSON, use status text
            errorMessage = response.statusText || errorMessage;
        }

        const error = new Error(errorMessage);
        error.status = response.status;
        error.response = response;
        return error;
    }

    /**
     * Main request method
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;

        return this.retryWithBackoff(async () => {
            const response = await this.fetchWithTimeout(url, options);

            if (!response.ok) {
                throw await this.parseError(response);
            }

            return response.json();
        });
    }

    // Convenience methods
    async get(endpoint, options) {
        return this.request(endpoint, { ...options, method: 'GET' });
    }

    async post(endpoint, data, options) {
        return this.request(endpoint, {
            ...options,
            method: 'POST',
            body: data
        });
    }
}

// Create instance
export const httpClient = new HTTPClient(window.CONFIG.API_URL, {
    timeout: 30000,
    maxRetries: 3,
    retryDelay: 1000
});
```

### 2. Refactor apiInteractions.js

```javascript
// apiInteractions.js - REFACTORED

import { httpClient } from './services/httpClient.js';

export async function submitJobToAPI(formData, cohortId = null, passphrase = null) {
    if (cohortId) {
        formData.append('cohort_id', cohortId);
    }
    if (passphrase) {
        formData.append('passphrase', passphrase);
    }

    // Now with retry, timeout, and centralized error parsing!
    return httpClient.post('/run-job/', formData);
}

export async function getJobStatus(jobId) {
    return httpClient.get(`/job-status/${encodeURIComponent(jobId)}/`);
}

export async function getCohortStatus(cohortId, passphrase = null) {
    let url = `/cohort-status/?cohort_id=${encodeURIComponent(cohortId)}`;
    if (passphrase) {
        url += `&passphrase=${encodeURIComponent(passphrase)}`;
    }
    return httpClient.get(url);
}

// Lines reduced from 500 to ~50!
```

---

## Implementation Steps

1. **Day 1: HTTPClient**
   - [ ] Create `services/httpClient.js`
   - [ ] Implement timeout with AbortController
   - [ ] Implement retry with exponential backoff
   - [ ] Centralize error parsing

2. **Day 2: Refactor API Calls**
   - [ ] Refactor `submitJobToAPI`
   - [ ] Refactor `getJobStatus`
   - [ ] Refactor `getCohortStatus`
   - [ ] Refactor `createCohort`

3. **Day 3: Testing**
   - [ ] Test retry logic (simulate failures)
   - [ ] Test timeout (simulate slow network)
   - [ ] Test error parsing
   - [ ] Verify all API calls still work

4. **Day 4: Documentation**
   - [ ] Document HTTPClient API
   - [ ] Add JSDoc comments
   - [ ] Update CLAUDE.md

---

## Success Criteria

- [ ] All API calls use HTTPClient
- [ ] Retry logic works (3 attempts for 5xx errors)
- [ ] Timeouts work (aborts after 30s)
- [ ] Single error parsing function
- [ ] apiInteractions.js reduced by 50%+ lines
- [ ] No duplicate code

---

**Created:** 2025-10-01
