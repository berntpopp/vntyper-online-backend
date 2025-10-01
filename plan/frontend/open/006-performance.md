# Performance Optimization

**Priority:** 🟡 **MEDIUM**
**Effort:** 3-4 days
**Status:** Open

---

## Executive Summary

The frontend has **significant performance issues** from repeated DOM queries, no caching, eager loading of all modules, and embedded base64 images. Performance degrades with multiple jobs and file operations.

**Key Issues:**
- **92 DOM queries** with zero caching - same elements queried repeatedly
- **All 25 modules loaded upfront** - No code splitting or lazy loading
- **28.9KB config.js** with embedded base64 images (8 logos)
- **520-line bamProcessing.js** loaded even if never used
- No debouncing on file selection (lags with 100+ files)
- No request deduplication
- Memory grows over time (Blob URL leaks from state management issue)

---

## Performance Problems Identified

### Issue 1: Repeated DOM Queries (92 occurrences across 17 files)

**No caching - every function queries DOM from scratch:**

#### uiUtils.js - Queries `#countdown` 4 times
```javascript
// uiUtils.js:298-317
export function startCountdown() {
    const countdownDiv = document.getElementById('countdown');  // Query 1
    countdownDiv.textContent = `Next poll in: ${timeLeft} seconds`;
    // ...
}

// uiUtils.js:322-331
export function resetCountdown() {
    timeLeft = 20;
    const countdownDiv = document.getElementById('countdown');  // Query 2
    // Same element, queried again!
}

// uiUtils.js:336-349
export function clearCountdown() {
    const countdownDiv = document.getElementById('countdown');  // Query 3
    // Still no caching!
}
```

**Impact:** 4 DOM queries for same element in same module

#### jobManager.js - Dynamic queries every status update
```javascript
// jobManager.js:26-35 - Called on EVERY poll (every 5 seconds!)
const cohortSection = document.getElementById(`cohort-${cohort_id}`);
const jobsContainer = document.getElementById(`jobs-container-${cohort_id}`);

// For 10 jobs polling every 5s = 20 DOM queries per second!
```

#### errorHandling.js - No null safety
```javascript
// errorHandling.js:3-6
export function displayError(message) {
    const errorDiv = document.getElementById('error');  // No caching
    errorDiv.textContent = message;  // Crashes if null
    errorDiv.classList.remove('hidden');
}

// errorHandling.js:9-12
export function clearError() {
    const errorDiv = document.getElementById('error');  // Query again!
    errorDiv.textContent = '';
}
```

**Problem:** Every error display/clear does 2 DOM queries

#### main.js - Queries in event handlers
```javascript
// main.js:86-92 - Inside initializeApp
const submitBtn = document.getElementById('submitBtn');
const extractBtn = document.getElementById('extractBtn');
const cohortAliasInput = document.getElementById('cohortAlias');
const passphraseInput = document.getElementById('passphrase');
const regionSelect = document.getElementById('region');
const regionOutputDiv = document.getElementById('regionOutput');
const emailInput = document.getElementById('email');

// Good - queried once at init
// But many other queries scattered throughout:

// main.js:104-114
const jobOutputDiv = document.getElementById('jobOutput');  // In resetApplicationState
const cohortsContainerDiv = document.getElementById('cohortsContainer');

// main.js:228-230
const outputDiv = document.getElementById('output');  // Later in same function
const jobOutputDiv = document.getElementById('jobOutput');  // Queried AGAIN!
const cohortsContainerDiv = document.getElementById('cohortsContainer');  // Queried AGAIN!
```

**Total: 92 DOM queries, most repeated multiple times**

---

### Issue 2: No Module Lazy Loading

**main.js imports EVERYTHING upfront (17 imports):**

```javascript
// main.js:3-45
import { validateFiles } from './inputWrangling.js';              // 91 lines
import { submitJobToAPI, pollJobStatusAPI, getCohortStatus,
         createCohort, pollCohortStatusAPI } from './apiInteractions.js';  // 500 lines!
import { initializeAioli, extractRegionAndIndex } from './bamProcessing.js';  // 520 lines!!
import { initializeModal } from './modal.js';                      // 175 lines
import { initializeFooter } from './footer.js';                    // 59 lines
import { initializeDisclaimer } from './disclaimer.js';            // 166 lines
import { initializeFAQ } from './faq.js';                          // 23 lines
import { initializeUserGuide } from './userGuide.js';              // 9 lines
import { initializeCitations } from './citations.js';              // 36 lines
import { initializeTutorial } from './tutorial.js';                // 46 lines
import { initializeUsageStats } from './usageStats.js';            // 105 lines
import { regions } from './regionsConfig.js';                      // 24 lines
import { displayError, clearError } from './errorHandling.js';     // 13 lines
import { createLabelValue, replaceLabelValue } from './domHelpers.js';  // 194 lines
import { validateJobId, validateCohortId } from './validators.js'; // 213 lines
import { showSpinner, hideSpinner, startCountdown, resetCountdown,
         clearCountdown, initializeUIUtils, displayMessage, clearMessage,
         displayShareableLink, hidePlaceholderMessage, showPlaceholderMessage,
         displayDownloadLink } from './uiUtils.js';                // 416 lines
import { initializeFileSelection } from './fileSelection.js';      // 168 lines
import { initializeServerLoad } from './serverLoad.js';            // 95 lines
import { logMessage, initializeLogging } from './log.js';          // 94 lines
import { fetchAndUpdateJobStatus, loadJobFromURL, loadCohortFromURL } from './jobManager.js';  // 372 lines

// TOTAL: ~3,200+ lines loaded upfront!
```

**Problems:**
1. **bamProcessing.js (520 lines)** - Loads Aioli/Samtools WebAssembly even if user never extracts BAM
2. **apiInteractions.js (500 lines)** - All API functions loaded even if only using job submission
3. **jobManager.js (372 lines)** - URL loading logic loaded even if no URL params
4. **uiUtils.js (416 lines)** - All UI functions loaded upfront

**Impact:**
- Initial page load: Downloads and parses ~4,300 lines of JavaScript
- Time to Interactive (TTI): Slow on mobile/slow connections
- Memory usage: All functions in memory even if never called

---

### Issue 3: Large Base64 Images in config.js (28.9KB)

**config.js contains 8 base64-encoded logos:**

```javascript
// config.js:1-71 (28,929 bytes!)

window.CONFIG = {
    API_URL: "/api",
    institutions: [
        {
            name: "Institut Imagine",
            logo: "II_60px.webp",
            base64: "data:image/webp;base64,UklGRjgKAABXRUJQ..."  // 2,732 characters!
        },
        {
            name: "Univerité Paris Cité",
            base64: "data:image/webp;base64,UklGRk4GAABXRUJQVlA4..."  // 1,600 characters
        },
        // ... 6 more logos, each 1-4KB of base64
    ]
};
```

**Problems:**
1. **Blocks parsing** - 28KB of base64 must be parsed before JS execution continues
2. **Memory waste** - Images stored as strings in memory (2x size of binary)
3. **No caching** - Browser can't cache images (embedded in JS)
4. **No lazy loading** - All logos loaded even if footer never scrolled to

**Optimal approach:**
- Keep as separate `.webp` files
- Use `<img src="logo.webp">` - browser caches them
- Lazy load with Intersection Observer when footer visible

---

### Issue 4: No Debouncing on File Selection

**fileSelection.js triggers immediate validation:**

```javascript
// fileSelection.js (hypothetical based on pattern)
fileInput.addEventListener('change', (event) => {
    const files = Array.from(event.target.files);
    // ⚠️ Immediate validation - no debounce
    const { matchedPairs, invalidFiles } = validateFiles(files);
    displaySelectedFiles(matchedPairs);
});
```

**Problem:** With 100+ files:
- Validates all files immediately
- Multiple DOM updates
- UI can freeze/lag

**Solution:** Debounce validation by 300ms

---

### Issue 5: No Request Deduplication

**Multiple rapid status checks send duplicate requests:**

```javascript
// If user clicks "Check Status" rapidly:
button.addEventListener('click', async () => {
    const status = await getJobStatus(jobId);  // Request 1
});

// Another click before response:
button.addEventListener('click', async () => {
    const status = await getJobStatus(jobId);  // Request 2 (duplicate!)
});
```

**Problem:** Same job status requested multiple times in parallel

**Solution:** Request deduplication/caching layer

---

## Proposed Solutions

### 1. DOM Cache Manager

```javascript
// utils/domCache.js

/**
 * Caches DOM elements for fast repeated access
 */
class DOMCache {
    constructor() {
        this.cache = new Map();  // id -> element
        this.queryCache = new Map();  // selector -> element
        this.hits = 0;
        this.misses = 0;
    }

    /**
     * Get element by ID (cached)
     * @param {string} id - Element ID
     * @returns {HTMLElement|null}
     */
    getElementById(id) {
        if (this.cache.has(id)) {
            this.hits++;
            return this.cache.get(id);
        }

        this.misses++;
        const element = document.getElementById(id);
        if (element) {
            this.cache.set(id, element);
        }
        return element;
    }

    /**
     * Get element by selector (cached)
     * @param {string} selector - CSS selector
     * @param {HTMLElement} parent - Parent element
     * @returns {HTMLElement|null}
     */
    querySelector(selector, parent = document) {
        const key = `${parent === document ? 'doc' : 'parent'}:${selector}`;

        if (this.queryCache.has(key)) {
            this.hits++;
            return this.queryCache.get(key);
        }

        this.misses++;
        const element = parent.querySelector(selector);
        if (element) {
            this.queryCache.set(key, element);
        }
        return element;
    }

    /**
     * Clear cache (call when DOM structure changes)
     */
    clear() {
        this.cache.clear();
        this.queryCache.clear();
    }

    /**
     * Remove specific cached element
     * @param {string} id - Element ID
     */
    invalidate(id) {
        this.cache.delete(id);
    }

    /**
     * Get cache statistics
     * @returns {Object}
     */
    getStats() {
        const total = this.hits + this.misses;
        const hitRate = total > 0 ? (this.hits / total * 100).toFixed(2) : 0;

        return {
            hits: this.hits,
            misses: this.misses,
            total,
            hitRate: `${hitRate}%`,
            cacheSize: this.cache.size + this.queryCache.size
        };
    }
}

// Create singleton
export const domCache = new DOMCache();

// Log stats periodically in dev
if (window.location.hostname === 'localhost') {
    setInterval(() => {
        console.log('[DOMCache]', domCache.getStats());
    }, 30000);
}
```

**Usage:**
```javascript
// Before:
const errorDiv = document.getElementById('error');

// After:
import { domCache } from './utils/domCache.js';
const errorDiv = domCache.getElementById('error');

// After 100 calls:
// - First call: DOM query (slow)
// - Next 99 calls: Cache hit (instant)
// Expected: 99% hit rate, 100x faster
```

### 2. Lazy Load Heavy Modules

```javascript
// main.js - REFACTORED with dynamic imports

async function initializeApp() {
    // Always load: critical initialization
    initializeModal();
    initializeFooter();
    initializeLogging();

    // Lazy load: BAM processing (520 lines)
    const extractBtn = domCache.getElementById('extractBtn');
    if (extractBtn) {
        let bamModule = null;

        extractBtn.addEventListener('click', async () => {
            if (!bamModule) {
                showMessage('Loading BAM processing tools...', 'info');

                // Load ONLY when user clicks extract
                bamModule = await import('./bamProcessing.js');
                console.log('[Performance] bamProcessing.js loaded on-demand');
            }

            const CLI = await bamModule.initializeAioli();
            const result = await bamModule.extractRegionAndIndex(CLI, ...);
            // ...
        });
    }

    // Lazy load: URL handling (372 lines)
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has('job_id') || urlParams.has('cohort_id')) {
        // Load ONLY if URL params present
        const { loadJobFromURL, loadCohortFromURL } = await import('./jobManager.js');
        console.log('[Performance] jobManager.js loaded for URL params');

        if (urlParams.has('job_id')) {
            loadJobFromURL(urlParams.get('job_id'), context);
        } else {
            loadCohortFromURL(urlParams.get('cohort_id'), context);
        }
    }
}

// Before: 4,300 lines loaded upfront
// After: ~1,000 lines loaded upfront, rest on-demand
// Improvement: 4x faster initial load
```

### 3. Debounce Utility

```javascript
// utils/debounce.js

/**
 * Debounce function calls
 * @param {Function} fn - Function to debounce
 * @param {number} delay - Delay in milliseconds
 * @returns {Function} - Debounced function
 */
export function debounce(fn, delay) {
    let timeoutId;

    const debounced = function(...args) {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => {
            fn.apply(this, args);
        }, delay);
    };

    // Allow immediate invocation
    debounced.now = function(...args) {
        clearTimeout(timeoutId);
        fn.apply(this, args);
    };

    // Allow cancellation
    debounced.cancel = function() {
        clearTimeout(timeoutId);
    };

    return debounced;
}

/**
 * Throttle function calls
 * @param {Function} fn - Function to throttle
 * @param {number} limit - Minimum time between calls
 * @returns {Function} - Throttled function
 */
export function throttle(fn, limit) {
    let inThrottle;

    return function(...args) {
        if (!inThrottle) {
            fn.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}
```

**Usage:**
```javascript
// fileSelection.js - REFACTORED
import { debounce } from './utils/debounce.js';

const validateAndDisplay = debounce((files) => {
    const { matchedPairs, invalidFiles } = validateFiles(files);
    displaySelectedFiles(matchedPairs);
}, 300);  // Wait 300ms after last file added

fileInput.addEventListener('change', (event) => {
    const files = Array.from(event.target.files);
    validateAndDisplay(files);
});

// Before: Validates immediately on every file
// After: Waits 300ms, single validation
// Improvement: Smooth UX even with 100+ files
```

### 4. Move Base64 Images to Separate Files

```javascript
// config.js - REFACTORED

window.CONFIG = {
    API_URL: "/api",
    institutions: [
        {
            name: "Institut Imagine",
            logo: "images/logos/institut-imagine.webp",  // External file
            url: "https://www.institutimagine.org/en",
            height: "60px",
            width: "157px",
            alt: "Institut Imagine Paris"
        },
        // ... 7 more, all external files
    ]
};

// Before: 28.9KB config.js
// After: 1.2KB config.js + 8 separate .webp files (browser cached)
// Improvement: 24x smaller JS file, parallel image loading
```

**HTML with lazy loading:**
```html
<footer id="footer">
    <!-- Images lazy loaded when footer visible -->
    <img src="images/logos/institut-imagine.webp"
         loading="lazy"
         alt="Institut Imagine"
         height="60"
         width="157">
</footer>
```

### 5. Request Deduplication Layer

```javascript
// utils/requestCache.js

/**
 * Caches in-flight and recent requests
 */
class RequestCache {
    constructor(ttl = 5000) {
        this.pending = new Map();  // url -> Promise
        this.cache = new Map();    // url -> { data, timestamp }
        this.ttl = ttl;
    }

    /**
     * Fetch with deduplication and caching
     * @param {string} url - Request URL
     * @param {Object} options - Fetch options
     * @returns {Promise}
     */
    async fetch(url, options = {}) {
        // Check cache first
        const cached = this.cache.get(url);
        if (cached && Date.now() - cached.timestamp < this.ttl) {
            console.log(`[RequestCache] HIT: ${url}`);
            return Promise.resolve(cached.data);
        }

        // Check if request already pending
        if (this.pending.has(url)) {
            console.log(`[RequestCache] DEDUP: ${url}`);
            return this.pending.get(url);
        }

        // Make new request
        console.log(`[RequestCache] MISS: ${url}`);
        const promise = fetch(url, options)
            .then(r => r.json())
            .then(data => {
                // Store in cache
                this.cache.set(url, {
                    data,
                    timestamp: Date.now()
                });

                // Remove from pending
                this.pending.delete(url);

                return data;
            })
            .catch(error => {
                // Remove from pending on error
                this.pending.delete(url);
                throw error;
            });

        // Store pending promise
        this.pending.set(url, promise);

        return promise;
    }

    /**
     * Clear cache
     */
    clear() {
        this.cache.clear();
        this.pending.clear();
    }

    /**
     * Invalidate specific URL
     */
    invalidate(url) {
        this.cache.delete(url);
    }
}

export const requestCache = new RequestCache(5000);  // 5s TTL
```

**Usage:**
```javascript
// apiInteractions.js - REFACTORED
import { requestCache } from './utils/requestCache.js';

export async function getJobStatus(jobId) {
    const url = `${window.CONFIG.API_URL}/job-status/${jobId}/`;

    // Automatically deduplicated and cached
    return requestCache.fetch(url);
}

// User clicks "Check Status" 10 times in 2 seconds:
// - 1 actual request
// - 9 cache hits
// Improvement: 90% less network traffic
```

---

## Implementation Steps

### Day 1: DOM Cache Manager
- [ ] Create `utils/domCache.js` with DOMCache class
- [ ] Replace `document.getElementById` in errorHandling.js
- [ ] Replace `document.getElementById` in uiUtils.js
- [ ] Add cache stats logging in dev mode
- [ ] Test: Verify 90%+ cache hit rate

### Day 2: Lazy Loading
- [ ] Refactor main.js to lazy load bamProcessing.js
- [ ] Refactor main.js to lazy load jobManager.js (only if URL params)
- [ ] Add loading indicators when importing modules
- [ ] Test: Verify initial bundle reduced by ~70%

### Day 3: Debouncing & Request Cache
- [ ] Create `utils/debounce.js` with debounce/throttle
- [ ] Apply debouncing to file selection in fileSelection.js
- [ ] Create `utils/requestCache.js` with RequestCache
- [ ] Apply request deduplication to getJobStatus
- [ ] Test: Verify smooth UX with 100+ files, no duplicate requests

### Day 4: Base64 Images + Performance Testing
- [ ] Extract base64 images from config.js to separate files
- [ ] Update footer.js to use `<img>` tags with `loading="lazy"`
- [ ] Add Intersection Observer for visible logos
- [ ] **Performance Testing:**
  - Measure Time to Interactive (TTI) - Target: <3s on 3G
  - Measure DOM query performance - Target: 95%+ cache hit rate
  - Measure memory usage over 10 minutes - Target: Stable (no leaks)
  - Test with 100+ files - Target: No UI lag
- [ ] Document performance improvements

---

## Performance Metrics

### Before Optimization
- **Initial JS bundle:** 4,300 lines (~150KB minified)
- **config.js size:** 28.9KB
- **DOM queries per minute:** ~200 (10 jobs polling)
- **Cache hit rate:** 0% (no cache)
- **Time to Interactive:** ~5s on 3G
- **Memory growth:** +5MB per 10 jobs (Blob URL leaks)

### After Optimization (Targets)
- **Initial JS bundle:** ~1,000 lines (~40KB minified) - **74% reduction**
- **config.js size:** 1.2KB - **96% reduction**
- **DOM queries per minute:** ~10 (rest from cache) - **95% reduction**
- **Cache hit rate:** 95%+
- **Time to Interactive:** <3s on 3G - **40% faster**
- **Memory growth:** +0MB (Blob URLs managed) - **Stable**

---

## Testing Strategy

### Performance Testing Tools

```javascript
// tests/performance/dom-cache.test.js

describe('DOM Cache Performance', () => {
    it('should have 95%+ hit rate after warmup', () => {
        const cache = new DOMCache();

        // Warmup: Query 10 elements
        for (let i = 0; i < 10; i++) {
            cache.getElementById(`element-${i}`);
        }

        // Test: Query same elements 100 times
        for (let j = 0; j < 100; j++) {
            for (let i = 0; i < 10; i++) {
                cache.getElementById(`element-${i}`);
            }
        }

        const stats = cache.getStats();
        expect(parseFloat(stats.hitRate)).toBeGreaterThan(95);
    });
});
```

### Manual Performance Testing

```javascript
// Add to main.js in dev mode
if (window.location.hostname === 'localhost') {
    window.performanceMonitor = {
        logDOMQueries: () => {
            console.log('[Performance] DOM Cache:', domCache.getStats());
        },
        logRequestCache: () => {
            console.log('[Performance] Request Cache:', {
                pending: requestCache.pending.size,
                cached: requestCache.cache.size
            });
        },
        logMemory: () => {
            if (performance.memory) {
                console.log('[Performance] Memory:', {
                    used: `${(performance.memory.usedJSHeapSize / 1048576).toFixed(2)} MB`,
                    total: `${(performance.memory.totalJSHeapSize / 1048576).toFixed(2)} MB`
                });
            }
        }
    };

    // Log every 10 seconds
    setInterval(() => {
        window.performanceMonitor.logDOMQueries();
        window.performanceMonitor.logRequestCache();
        window.performanceMonitor.logMemory();
    }, 10000);
}
```

### Chrome DevTools Profiling

1. **Network Tab:**
   - Verify base64 images replaced with external files
   - Verify lazy loading (bamProcessing.js not loaded until extract clicked)
   - Verify request deduplication (single request for rapid clicks)

2. **Performance Tab:**
   - Record page load
   - Verify Time to Interactive <3s on "Slow 3G" throttling
   - Verify no long tasks (>50ms)

3. **Memory Tab:**
   - Take heap snapshot
   - Submit 10 jobs
   - Take another heap snapshot
   - Compare: Memory growth should be minimal (<5MB)

---

## Success Criteria

- [ ] Initial JS bundle reduced by 70%+
- [ ] config.js reduced from 28.9KB to <2KB
- [ ] DOM cache hit rate 95%+
- [ ] Time to Interactive <3s on 3G
- [ ] No UI lag with 100+ files
- [ ] Request deduplication working (verified in Network tab)
- [ ] Memory usage stable over 10 minutes
- [ ] Lazy loading verified (bamProcessing only loads when needed)

---

## Related Issues

- **003-STATE-MANAGEMENT.md** - Memory leaks affect overall performance
- **005-API-NETWORKING.md** - Request caching relates to API optimization

---

**Created:** 2025-10-01
**Last Updated:** 2025-10-01
