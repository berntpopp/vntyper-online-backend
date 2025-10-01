# Error Handling & Resilience

**Priority:** 🔴 **CRITICAL**
**Effort:** 3-4 days
**Status:** Open

---

## Executive Summary

The frontend has **minimal error handling infrastructure** that will cause application crashes and poor user experience. The `errorHandling.js` module is only 13 lines and provides no safety, recovery, or logging capabilities.

**Key Issues:**
- No null safety on DOM queries (will crash if elements missing)
- No error boundaries for async operations
- No global error handler
- Inconsistent error handling across 59 try-catch blocks
- No retry logic or fallback strategies
- Errors silently swallowed in multiple locations

---

## Current State

### errorHandling.js (Complete File - 13 lines)

```javascript
// frontend/resources/js/errorHandling.js

export function displayError(message) {
    const errorDiv = document.getElementById('error');
    errorDiv.textContent = message;  // ⚠️ CRASHES if #error doesn't exist
    errorDiv.classList.remove('hidden');
}

export function clearError() {
    const errorDiv = document.getElementById('error');
    errorDiv.textContent = '';
    errorDiv.classList.add('hidden');
}
```

**Problems:**
1. **No null checks** - Immediate crash if `#error` element is missing
2. **No error logging** - Lost debugging information
3. **No error types** - All errors treated identically
4. **No recovery** - Can't recover from errors
5. **No history** - Can't track error patterns

---

## Identified Critical Issues

### Issue 1: Unsafe DOM Queries (92 occurrences)

Found **92 `document.getElementById/querySelector` calls** across 17 files with **zero null checks**.

**Example from main.js:100-106:**
```javascript
const jobOutputDiv = document.getElementById('jobOutput');
if (jobOutputDiv) {
    jobOutputDiv.innerHTML = '';  // Good - has null check
}

const cohortSection = document.getElementById(`cohort-${cohort_id}`);
// ⚠️ NO null check - immediate use:
cohortSection.appendChild(element);  // CRASH if element doesn't exist
```

**Impact:** Application crashes if HTML structure changes or elements aren't loaded yet.

---

### Issue 2: No Global Error Handler

**No `window.onerror` or `window.onunhandledrejection` handlers**

Unhandled errors and promise rejections silently fail or show browser's default ugly error page.

```javascript
// Currently: NO global error handler

// Should have:
window.addEventListener('error', (event) => {
    ErrorHandler.handleGlobalError(event.error, event);
});

window.addEventListener('unhandledrejection', (event) => {
    ErrorHandler.handleGlobalError(event.reason, event);
});
```

---

### Issue 3: Inconsistent Error Handling (59 try-catch blocks)

Found 59 try-catch blocks across 8 files with **inconsistent patterns**:

**apiInteractions.js:23-77** - Good pattern:
```javascript
try {
    const response = await fetch(...);
    if (!response.ok) {
        let errorMessage = 'Failed to submit job(s).';
        try {
            const errorData = await response.json();
            // Parse error details
        } catch (e) {
            logMessage('Error parsing error response', 'error');
        }
        throw new Error(errorMessage);
    }
    return await response.json();
} catch (error) {
    logMessage(`Error: ${error.message}`, 'error');
    throw error;  // ✅ Re-throws for caller to handle
}
```

**bamProcessing.js:30-37** - Poor pattern:
```javascript
try {
    const CLI = await new Aioli(["samtools/1.17"]);
    return CLI;
} catch (err) {
    logMessage(`Error: ${err.message}`, 'error');
    const errorDiv = document.getElementById("error");
    if (errorDiv) {  // At least has null check
        errorDiv.textContent = "Failed to initialize...";
    }
    throw err;  // Good - re-throws
}
```

**main.js:241-272** - Mixed pattern:
```javascript
try {
    showSpinner();
    const CLI = await initializeAioli();
    const { matchedPairs, invalidFiles } = validateFiles(...);

    if (invalidFiles.length > 0) {
        displayError(`Some files were invalid...`);  // No null check in displayError!
    }

    if (matchedPairs.length === 0) {
        displayError('No valid BAM and BAI file pairs...');
        hideSpinner();
        clearCountdown();
        return;  // ⚠️ Early return without cleanup in finally
    }
} catch (error) {
    // ⚠️ NO catch block - errors bubble up unhandled!
}
```

**Inconsistencies:**
- Some functions re-throw, some swallow
- Some show user errors, some only log
- Some clean up resources, some don't
- No standard error format

---

### Issue 4: Timer Cleanup Issues (Found in 5 files)

**uiUtils.js:5-6** - Global countdown state:
```javascript
let countdownInterval = null;
let timeLeft = 20;
```

**Problem:** If multiple jobs submitted, timer can leak or conflict.

**Polling in apiInteractions.js:203-249:**
```javascript
export function pollJobStatusAPI(jobId, onStatusUpdate, ...) {
    if (activeJobPolls.has(jobId)) {
        logMessage(`Polling already active for Job ID: ${jobId}`, 'warning');
        return () => {};  // ⚠️ Returns no-op instead of actual stop function
    }

    activeJobPolls.add(jobId);
    let isPolling = true;

    const poll = async () => {
        if (!isPolling) return;

        try {
            const data = await getJobStatus(jobId);
            // ...
            setTimeout(poll, POLL_INTERVAL);  // ⚠️ No handle stored, can't cancel
        } catch (error) {
            // ...
            setTimeout(poll, POLL_INTERVAL);  // Retries even on error
        }
    };

    poll();  // Start immediately

    return () => {
        isPolling = false;
        activeJobPolls.delete(jobId);
    };
}
```

**Problems:**
- `setTimeout` handle not stored - can't be cleared externally
- If page navigates away, timers keep running (memory leak)
- Multiple jobs can create cascading timers

---

### Issue 5: No Error Recovery Strategies

**No retry logic, no fallbacks, no degraded modes**

```javascript
// Current: One attempt, then fail
const response = await fetch(url);
if (!response.ok) throw new Error('Failed');

// Should have: Retry with exponential backoff
const response = await retryWithBackoff(() => fetch(url), {
    maxRetries: 3,
    baseDelay: 1000,
    maxDelay: 10000
});
```

---

## Proposed Solution

### 1. Create Robust ErrorHandler Class

```javascript
// frontend/resources/js/errorHandling.js

export const ErrorLevel = Object.freeze({
    INFO: 'info',
    WARNING: 'warning',
    ERROR: 'error',
    CRITICAL: 'critical'
});

export class ErrorHandler {
    constructor() {
        this.errorHistory = [];
        this.maxHistorySize = 100;
        this.errorCallbacks = new Map();
    }

    /**
     * Handle any error with context
     * @param {Error|string} error - The error to handle
     * @param {Object} context - Additional context
     * @param {ErrorLevel} level - Severity level
     */
    handleError(error, context = {}, level = ErrorLevel.ERROR) {
        const errorEntry = {
            message: error?.message || String(error),
            stack: error?.stack,
            timestamp: new Date().toISOString(),
            level,
            context,
            url: window.location.href,
            userAgent: navigator.userAgent
        };

        // Store in history
        this.errorHistory.push(errorEntry);
        if (this.errorHistory.length > this.maxHistorySize) {
            this.errorHistory.shift();
        }

        // Log to console
        console.error('[ErrorHandler]', errorEntry);

        // Display to user (safely)
        this.displayError(errorEntry.message, level);

        // Trigger callbacks
        this.triggerCallbacks(errorEntry);

        return errorEntry;
    }

    /**
     * Safely display error to user
     * @param {string} message - Error message
     * @param {ErrorLevel} level - Severity level
     */
    displayError(message, level = ErrorLevel.ERROR) {
        const errorDiv = document.getElementById('error');
        if (!errorDiv) {
            console.error('Error div not found. Message:', message);
            return;
        }

        errorDiv.textContent = message;
        errorDiv.className = `error error-${level}`;
        errorDiv.classList.remove('hidden');
    }

    /**
     * Clear error display
     */
    clearError() {
        const errorDiv = document.getElementById('error');
        if (errorDiv) {
            errorDiv.textContent = '';
            errorDiv.classList.add('hidden');
        }
    }

    /**
     * Register global error handlers
     */
    registerGlobalHandlers() {
        window.addEventListener('error', (event) => {
            this.handleError(event.error, {
                type: 'uncaught',
                filename: event.filename,
                lineno: event.lineno,
                colno: event.colno
            }, ErrorLevel.CRITICAL);
            event.preventDefault();
        });

        window.addEventListener('unhandledrejection', (event) => {
            this.handleError(event.reason, {
                type: 'unhandled_promise',
                promise: event.promise
            }, ErrorLevel.CRITICAL);
            event.preventDefault();
        });
    }

    /**
     * Wrap async function with error handling
     * @param {Function} fn - Async function to wrap
     * @param {Object} context - Context for errors
     * @returns {Function} - Wrapped function
     */
    wrapAsync(fn, context = {}) {
        return async (...args) => {
            try {
                return await fn(...args);
            } catch (error) {
                this.handleError(error, { ...context, args });
                throw error;
            }
        };
    }

    /**
     * Retry function with exponential backoff
     * @param {Function} fn - Function to retry
     * @param {Object} options - Retry options
     * @returns {Promise} - Result of function
     */
    async retryWithBackoff(fn, options = {}) {
        const {
            maxRetries = 3,
            baseDelay = 1000,
            maxDelay = 10000,
            onRetry = null
        } = options;

        let lastError;

        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                return await fn();
            } catch (error) {
                lastError = error;

                if (attempt < maxRetries) {
                    const delay = Math.min(
                        baseDelay * Math.pow(2, attempt),
                        maxDelay
                    );

                    if (onRetry) {
                        onRetry(attempt + 1, delay, error);
                    }

                    await new Promise(resolve => setTimeout(resolve, delay));
                } else {
                    this.handleError(error, {
                        retries: attempt,
                        function: fn.name
                    });
                }
            }
        }

        throw lastError;
    }

    /**
     * Get error history
     * @param {ErrorLevel} level - Filter by level
     * @returns {Array} - Error entries
     */
    getHistory(level = null) {
        if (level) {
            return this.errorHistory.filter(e => e.level === level);
        }
        return [...this.errorHistory];
    }

    /**
     * Register callback for errors
     * @param {string} id - Unique callback ID
     * @param {Function} callback - Callback function
     */
    onError(id, callback) {
        this.errorCallbacks.set(id, callback);
    }

    /**
     * Trigger error callbacks
     * @param {Object} errorEntry - Error entry
     */
    triggerCallbacks(errorEntry) {
        for (const [id, callback] of this.errorCallbacks) {
            try {
                callback(errorEntry);
            } catch (error) {
                console.error(`Error in callback ${id}:`, error);
            }
        }
    }
}

// Create singleton instance
export const errorHandler = new ErrorHandler();

// Legacy exports for backwards compatibility
export function displayError(message) {
    errorHandler.displayError(message, ErrorLevel.ERROR);
}

export function clearError() {
    errorHandler.clearError();
}
```

### 2. Add Safe DOM Helper

```javascript
// frontend/resources/js/domHelpers.js (add to existing file)

/**
 * Safely query DOM element with error handling
 * @param {string} selector - CSS selector
 * @param {Element} parent - Parent element (default: document)
 * @returns {Element|null} - Element or null
 */
export function safeQuerySelector(selector, parent = document) {
    try {
        const element = parent.querySelector(selector);
        if (!element) {
            console.warn(`Element not found: ${selector}`);
        }
        return element;
    } catch (error) {
        console.error(`Error querying selector ${selector}:`, error);
        return null;
    }
}

/**
 * Safely get element by ID with error handling
 * @param {string} id - Element ID
 * @returns {Element|null} - Element or null
 */
export function safeGetElementById(id) {
    try {
        const element = document.getElementById(id);
        if (!element) {
            console.warn(`Element not found: #${id}`);
        }
        return element;
    } catch (error) {
        console.error(`Error getting element #${id}:`, error);
        return null;
    }
}

/**
 * Require element (throw if not found)
 * @param {string} id - Element ID
 * @returns {Element} - Element
 * @throws {Error} - If element not found
 */
export function requireElementById(id) {
    const element = document.getElementById(id);
    if (!element) {
        throw new Error(`Required element not found: #${id}`);
    }
    return element;
}
```

### 3. Update main.js Initialization

```javascript
// frontend/resources/js/main.js (add at top of initializeApp)

import { errorHandler } from './errorHandling.js';

async function initializeApp() {
    // Register global error handlers FIRST
    errorHandler.registerGlobalHandlers();

    // Wrap critical initialization in error handler
    try {
        // ... existing initialization code
    } catch (error) {
        errorHandler.handleError(error, {
            phase: 'initialization'
        }, ErrorLevel.CRITICAL);

        // Show user-friendly error
        displayError('Failed to initialize application. Please refresh the page.');
    }
}
```

---

## Implementation Steps

1. **Day 1: Core ErrorHandler**
   - [ ] Expand `errorHandling.js` with full ErrorHandler class
   - [ ] Add ErrorLevel enum
   - [ ] Implement error history and callbacks
   - [ ] Register global handlers

2. **Day 2: DOM Safety**
   - [ ] Add safe DOM helpers to `domHelpers.js`
   - [ ] Replace unsafe `document.getElementById` calls in critical paths
   - [ ] Add null checks to all DOM manipulations

3. **Day 3: Async Error Boundaries**
   - [ ] Wrap all async operations with error handling
   - [ ] Implement retry logic for API calls
   - [ ] Add proper cleanup in finally blocks

4. **Day 4: Testing & Polish**
   - [ ] Test error scenarios (missing elements, network failures)
   - [ ] Ensure all timers/intervals are cleaned up
   - [ ] Verify error messages are user-friendly
   - [ ] Document error handling patterns

---

## Testing Strategy

### Manual Testing
1. Remove `#error` element from HTML → Should not crash
2. Simulate network failure → Should show retry attempts
3. Submit invalid files → Should show clear error message
4. Navigate away during polling → Should cleanup timers

### Automated Testing
```javascript
// tests/unit/errorHandling.test.js
import { errorHandler, ErrorLevel } from '../errorHandling.js';

describe('ErrorHandler', () => {
    test('handles missing error div gracefully', () => {
        document.body.innerHTML = ''; // No error div
        expect(() => {
            errorHandler.displayError('Test error');
        }).not.toThrow();
    });

    test('stores error history', () => {
        errorHandler.handleError(new Error('Test'), {}, ErrorLevel.ERROR);
        const history = errorHandler.getHistory();
        expect(history.length).toBeGreaterThan(0);
    });

    test('retries with backoff', async () => {
        let attempts = 0;
        const fn = async () => {
            attempts++;
            if (attempts < 3) throw new Error('Fail');
            return 'success';
        };

        const result = await errorHandler.retryWithBackoff(fn, {
            maxRetries: 3,
            baseDelay: 10
        });

        expect(result).toBe('success');
        expect(attempts).toBe(3);
    });
});
```

---

## Success Criteria

- [ ] No crashes when DOM elements are missing
- [ ] All uncaught errors and promise rejections are handled
- [ ] Error history available for debugging
- [ ] Retry logic for network requests
- [ ] All timers/intervals properly cleaned up
- [ ] User-friendly error messages
- [ ] Console logs include context and stack traces
- [ ] Error handling is consistent across all modules

---

## Related Issues

- **003-STATE-MANAGEMENT.md** - Timer cleanup overlaps with state management
- **005-API-NETWORKING.md** - Retry logic relates to API error handling

---

**Created:** 2025-10-01
**Last Updated:** 2025-10-01
