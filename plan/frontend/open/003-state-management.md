# State Management & Memory Leaks

**Priority:** 🟠 **HIGH**
**Effort:** 4-5 days
**Status:** Open

---

## Executive Summary

The frontend has **critical memory leaks** and **scattered state** across multiple modules with no central coordination. Blob URLs are never revoked, timers aren't cleaned up properly, and race conditions exist in polling logic.

**Key Issues:**
- **Blob URL memory leaks** - `URL.createObjectURL()` called without `revokeObjectURL()`
- **Timer leaks** - Global countdown interval can conflict across multiple jobs
- **Race conditions** - Polling can start multiple times for same job
- **Scattered state** - No single source of truth, state spread across 6+ modules
- **No lifecycle management** - Resources not cleaned up on page navigation

---

## Critical Memory Leaks

### Issue 1: Blob URL Leak in main.js (lines 612-652)

**CRITICAL MEMORY LEAK:**

```javascript
// main.js:612-613
const downloadBamUrl = URL.createObjectURL(subsetBamBlob);
const downloadBaiUrl = URL.createObjectURL(subsetBaiBlob);

// ... 40 lines later ...

// main.js:652 - ONLY ONE URL IS REVOKED!
URL.revokeObjectURL(link.href);  // ⚠️ Only revokes BAM, not BAI!
```

**Problem:** Two Blob URLs created, only one revoked. The BAI URL **leaks memory until page reload**.

**Impact:** Each file extraction creates ~50-500MB Blob URL that never gets freed.

**Also in citations.js:28-35** - This one IS correct:
```javascript
const url = URL.createObjectURL(blob);
const link = document.createElement('a');
link.href = url;
link.download = 'vntyper_citation.ris';
link.click();
URL.revokeObjectURL(url);  // ✅ Correctly revoked
```

---

### Issue 2: Global Countdown Timer Conflicts (uiUtils.js:5-349)

**RACE CONDITION & MEMORY LEAK:**

```javascript
// uiUtils.js:5-6 - MODULE-LEVEL GLOBALS
let countdownInterval = null;
let timeLeft = 20;

// uiUtils.js:298-313
export function startCountdown() {
    const countdownDiv = document.getElementById('countdown');
    countdownDiv.textContent = `Next poll in: ${timeLeft} seconds`;

    // ⚠️ NO CHECK if countdownInterval already exists!
    countdownInterval = setInterval(() => {
        timeLeft--;
        if (timeLeft > 0) {
            countdownDiv.textContent = `Next poll in: ${timeLeft} seconds`;
        } else {
            timeLeft = 20;  // ⚠️ Resets automatically in infinite loop!
            countdownDiv.textContent = `Next poll in: ${timeLeft} seconds`;
        }
    }, 1000);
}

// uiUtils.js:336-349
export function clearCountdown() {
    if (countdownInterval) {
        clearInterval(countdownInterval);
        countdownInterval = null;
    }
    // ...
}
```

**Problems:**
1. **No cleanup check** - Starting countdown twice creates two intervals, only one handle is saved
2. **Infinite loop** - Timer resets itself automatically at 0, never stops
3. **Shared state** - Multiple jobs share same countdown, conflicts inevitable
4. **Memory leak** - Old interval lost but keeps running

**Scenario that breaks:**
```javascript
// User submits Job A
startCountdown();  // Interval 1 starts

// User submits Job B before A completes
startCountdown();  // Interval 2 starts, Interval 1 LOST but still running!

// clearCountdown() is called
clearCountdown();  // Only stops Interval 2, Interval 1 runs forever
```

---

### Issue 3: Polling Race Conditions (apiInteractions.js:8-249)

**PARTIAL FIX, STILL HAS ISSUES:**

```javascript
// apiInteractions.js:8-13
const activeJobPolls = new Set();  // ✅ Good - tracks active polls
const activeCohortPolls = new Set();

// apiInteractions.js:203-249
export function pollJobStatusAPI(jobId, onStatusUpdate, ...) {
    // ✅ Good - prevents duplicate polling
    if (activeJobPolls.has(jobId)) {
        logMessage(`Polling already active for Job ID: ${jobId}`, 'warning');
        return () => {};  // ⚠️ Returns no-op function
    }

    activeJobPolls.add(jobId);
    let isPolling = true;

    const poll = async () => {
        if (!isPolling) return;

        try {
            const data = await getJobStatus(jobId);
            onStatusUpdate(data.status);

            if (data.status === 'completed') {
                onComplete();
                isPolling = false;
                activeJobPolls.delete(jobId);
                return;
            } else if (data.status === 'failed') {
                onError(data.error);
                isPolling = false;
                activeJobPolls.delete(jobId);
                return;
            }

            // ⚠️ No handle stored, can't cancel externally
            setTimeout(poll, POLL_INTERVAL);
        } catch (error) {
            onError(error);
            // ⚠️ Keeps retrying forever on errors
            setTimeout(poll, POLL_INTERVAL);
        }
    };

    poll();

    // Returns stop function
    return () => {
        isPolling = false;
        activeJobPolls.delete(jobId);
        // ⚠️ But setTimeout still runs one more time!
    };
}
```

**Problems:**
1. **No timeout handle** - `setTimeout` not stored, can't be cancelled
2. **Infinite error retries** - Errors don't stop polling
3. **Stop function incomplete** - Doesn't cancel pending timeout
4. **No max retries** - Will poll forever if backend is down

---

### Issue 4: Scattered State Across Modules

**State is spread across at least 6 different locations:**

1. **main.js (lines 82-99):**
   ```javascript
   const displayedCohorts = new Set();  // Tracks displayed cohorts
   let selectedFiles = [];              // File selection state
   ```

2. **uiUtils.js (lines 5-6):**
   ```javascript
   let countdownInterval = null;  // Timer state
   let timeLeft = 20;             // Countdown value
   ```

3. **apiInteractions.js (lines 8-13):**
   ```javascript
   const activeJobPolls = new Set();    // Active job polls
   const activeCohortPolls = new Set(); // Active cohort polls
   ```

4. **fileSelection.js:**
   ```javascript
   let selectedFiles = [];  // Duplicate of main.js state!
   ```

5. **bamProcessing.js:**
   ```javascript
   let CLI = null;  // Aioli CLI instance
   ```

6. **serverLoad.js:**
   ```javascript
   let updateInterval = null;  // Server monitoring interval
   ```

**Problems:**
- **No single source of truth** - Same data duplicated in multiple places
- **Synchronization issues** - Changes in one place don't update others
- **Hard to debug** - State scattered across 25 files
- **No state history** - Can't undo or replay actions

---

## Proposed Solution

### 1. Create BlobURLManager for Automatic Cleanup

```javascript
// frontend/resources/js/blobManager.js

/**
 * Manages Blob URLs with automatic cleanup
 */
export class BlobURLManager {
    constructor() {
        this.urls = new Map();  // url -> { blob, timestamp, metadata }
    }

    /**
     * Create a blob URL and track it
     * @param {Blob} blob - The blob to create URL for
     * @param {Object} metadata - Optional metadata
     * @returns {string} - The blob URL
     */
    create(blob, metadata = {}) {
        const url = URL.createObjectURL(blob);
        this.urls.set(url, {
            blob,
            timestamp: Date.now(),
            metadata
        });
        console.log(`[BlobURLManager] Created URL: ${url}`, metadata);
        return url;
    }

    /**
     * Revoke a specific blob URL
     * @param {string} url - The URL to revoke
     */
    revoke(url) {
        if (this.urls.has(url)) {
            URL.revokeObjectURL(url);
            this.urls.delete(url);
            console.log(`[BlobURLManager] Revoked URL: ${url}`);
        }
    }

    /**
     * Revoke all blob URLs
     */
    revokeAll() {
        for (const url of this.urls.keys()) {
            URL.revokeObjectURL(url);
        }
        const count = this.urls.size;
        this.urls.clear();
        console.log(`[BlobURLManager] Revoked ${count} URLs`);
    }

    /**
     * Revoke URLs older than maxAge milliseconds
     * @param {number} maxAge - Max age in milliseconds
     */
    revokeOld(maxAge = 60000) {  // Default: 1 minute
        const now = Date.now();
        let revokedCount = 0;

        for (const [url, data] of this.urls.entries()) {
            if (now - data.timestamp > maxAge) {
                URL.revokeObjectURL(url);
                this.urls.delete(url);
                revokedCount++;
            }
        }

        if (revokedCount > 0) {
            console.log(`[BlobURLManager] Revoked ${revokedCount} old URLs`);
        }
    }

    /**
     * Get all tracked URLs
     * @returns {Array} - Array of URL info
     */
    getAll() {
        return Array.from(this.urls.entries()).map(([url, data]) => ({
            url,
            ...data
        }));
    }
}

// Create singleton instance
export const blobManager = new BlobURLManager();

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    blobManager.revokeAll();
});

// Periodic cleanup of old URLs (every 60 seconds)
setInterval(() => {
    blobManager.revokeOld(300000);  // 5 minutes
}, 60000);
```

### 2. Create Centralized StateManager

```javascript
// frontend/resources/js/stateManager.js

/**
 * Centralized state management
 */
export class StateManager {
    constructor() {
        this.state = {
            // File selection
            selectedFiles: [],

            // Job tracking
            jobs: new Map(),  // jobId -> { status, data, ... }
            activeJobPolls: new Set(),

            // Cohort tracking
            cohorts: new Map(),  // cohortId -> { alias, jobs, ... }
            activeCohortPolls: new Set(),
            displayedCohorts: new Set(),

            // UI state
            countdown: {
                interval: null,
                timeLeft: 20,
                isActive: false
            },

            // Aioli CLI
            cli: null,

            // Server monitoring
            serverLoad: {
                interval: null,
                data: null
            }
        };

        this.listeners = new Map();  // event -> Set of callbacks
        this.history = [];  // State change history for debugging
        this.maxHistory = 50;
    }

    /**
     * Get current state (immutable)
     * @returns {Object} - Current state
     */
    getState() {
        return JSON.parse(JSON.stringify(this.state));
    }

    /**
     * Get specific state value
     * @param {string} path - Dot-notation path (e.g., 'countdown.timeLeft')
     * @returns {*} - State value
     */
    get(path) {
        return path.split('.').reduce((obj, key) => obj?.[key], this.state);
    }

    /**
     * Set state value and notify listeners
     * @param {string} path - Dot-notation path
     * @param {*} value - New value
     */
    set(path, value) {
        const keys = path.split('.');
        const lastKey = keys.pop();
        const target = keys.reduce((obj, key) => obj[key], this.state);

        const oldValue = target[lastKey];
        target[lastKey] = value;

        // Record change in history
        this.history.push({
            timestamp: Date.now(),
            path,
            oldValue,
            newValue: value
        });

        if (this.history.length > this.maxHistory) {
            this.history.shift();
        }

        // Notify listeners
        this.emit(path, value, oldValue);

        console.log(`[StateManager] ${path} changed:`, oldValue, '->', value);
    }

    /**
     * Add a job
     * @param {string} jobId - Job ID
     * @param {Object} data - Job data
     */
    addJob(jobId, data) {
        this.state.jobs.set(jobId, {
            ...data,
            createdAt: Date.now()
        });
        this.emit('jobs.added', jobId, data);
    }

    /**
     * Update job status
     * @param {string} jobId - Job ID
     * @param {string} status - New status
     */
    updateJobStatus(jobId, status) {
        const job = this.state.jobs.get(jobId);
        if (job) {
            job.status = status;
            job.updatedAt = Date.now();
            this.emit('jobs.updated', jobId, job);
        }
    }

    /**
     * Start countdown timer (single instance only)
     */
    startCountdown() {
        // Clear any existing countdown first
        this.clearCountdown();

        this.state.countdown.isActive = true;
        this.state.countdown.timeLeft = 20;

        this.state.countdown.interval = setInterval(() => {
            this.state.countdown.timeLeft--;

            if (this.state.countdown.timeLeft <= 0) {
                this.state.countdown.timeLeft = 20;
            }

            this.emit('countdown.tick', this.state.countdown.timeLeft);
        }, 1000);

        this.emit('countdown.started');
    }

    /**
     * Clear countdown timer
     */
    clearCountdown() {
        if (this.state.countdown.interval) {
            clearInterval(this.state.countdown.interval);
            this.state.countdown.interval = null;
            this.state.countdown.isActive = false;
            this.emit('countdown.stopped');
        }
    }

    /**
     * Cleanup all resources
     */
    cleanup() {
        // Clear countdown
        this.clearCountdown();

        // Clear server monitoring
        if (this.state.serverLoad.interval) {
            clearInterval(this.state.serverLoad.interval);
            this.state.serverLoad.interval = null;
        }

        // Stop all active polls
        this.state.activeJobPolls.clear();
        this.state.activeCohortPolls.clear();

        this.emit('cleanup');
        console.log('[StateManager] Cleanup complete');
    }

    /**
     * Register event listener
     * @param {string} event - Event name
     * @param {Function} callback - Callback function
     * @returns {Function} - Unsubscribe function
     */
    on(event, callback) {
        if (!this.listeners.has(event)) {
            this.listeners.set(event, new Set());
        }
        this.listeners.get(event).add(callback);

        // Return unsubscribe function
        return () => {
            this.listeners.get(event)?.delete(callback);
        };
    }

    /**
     * Emit event to listeners
     * @param {string} event - Event name
     * @param {...*} args - Arguments to pass to listeners
     */
    emit(event, ...args) {
        const listeners = this.listeners.get(event);
        if (listeners) {
            for (const callback of listeners) {
                try {
                    callback(...args);
                } catch (error) {
                    console.error(`Error in listener for ${event}:`, error);
                }
            }
        }
    }

    /**
     * Get state change history
     * @returns {Array} - History entries
     */
    getHistory() {
        return [...this.history];
    }
}

// Create singleton instance
export const stateManager = new StateManager();

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    stateManager.cleanup();
});
```

### 3. Create PollingManager to Prevent Race Conditions

```javascript
// frontend/resources/js/pollingManager.js

import { stateManager } from './stateManager.js';

/**
 * Manages polling operations with deduplication
 */
export class PollingManager {
    constructor() {
        this.activePolls = new Map();  // id -> { stop, status, ... }
    }

    /**
     * Start polling with automatic deduplication
     * @param {string} id - Unique poll ID
     * @param {Function} pollFn - Async function to poll
     * @param {Object} options - Polling options
     * @returns {Function} - Stop function
     */
    start(id, pollFn, options = {}) {
        const {
            interval = 5000,
            maxRetries = 10,
            onUpdate = null,
            onComplete = null,
            onError = null
        } = options;

        // If already polling, return existing stop function
        if (this.activePolls.has(id)) {
            console.warn(`[PollingManager] Already polling ${id}`);
            return this.activePolls.get(id).stop;
        }

        let isPolling = true;
        let retries = 0;
        let timeoutHandle = null;

        const stop = () => {
            isPolling = false;
            if (timeoutHandle) {
                clearTimeout(timeoutHandle);
                timeoutHandle = null;
            }
            this.activePolls.delete(id);
            console.log(`[PollingManager] Stopped polling ${id}`);
        };

        const poll = async () => {
            if (!isPolling) return;

            try {
                const result = await pollFn();

                if (onUpdate) {
                    onUpdate(result);
                }

                // Check if polling should continue
                if (result.status === 'completed' || result.status === 'failed') {
                    if (onComplete) {
                        onComplete(result);
                    }
                    stop();
                    return;
                }

                // Schedule next poll
                retries = 0;  // Reset retries on success
                timeoutHandle = setTimeout(poll, interval);

            } catch (error) {
                retries++;

                if (onError) {
                    onError(error);
                }

                if (retries >= maxRetries) {
                    console.error(`[PollingManager] Max retries reached for ${id}`);
                    stop();
                    return;
                }

                // Exponential backoff
                const backoffDelay = Math.min(interval * Math.pow(2, retries), 60000);
                timeoutHandle = setTimeout(poll, backoffDelay);
            }
        };

        // Store polling info
        this.activePolls.set(id, {
            stop,
            startedAt: Date.now(),
            retries
        });

        // Start polling
        poll();

        console.log(`[PollingManager] Started polling ${id}`);
        return stop;
    }

    /**
     * Stop specific poll
     * @param {string} id - Poll ID
     */
    stop(id) {
        const poll = this.activePolls.get(id);
        if (poll) {
            poll.stop();
        }
    }

    /**
     * Stop all active polls
     */
    stopAll() {
        for (const [id, poll] of this.activePolls.entries()) {
            poll.stop();
        }
        console.log(`[PollingManager] Stopped ${this.activePolls.size} polls`);
    }

    /**
     * Get active poll IDs
     * @returns {Array} - Active poll IDs
     */
    getActive() {
        return Array.from(this.activePolls.keys());
    }
}

// Create singleton instance
export const pollingManager = new PollingManager();

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    pollingManager.stopAll();
});
```

---

## Implementation Steps

1. **Day 1: BlobURLManager**
   - [ ] Create `blobManager.js` with BlobURLManager class
   - [ ] Replace `URL.createObjectURL()` calls in main.js and citations.js
   - [ ] Fix BAI URL leak in main.js:652
   - [ ] Add automatic cleanup on page unload

2. **Day 2-3: StateManager**
   - [ ] Create `stateManager.js` with centralized state
   - [ ] Migrate countdown state from uiUtils.js
   - [ ] Migrate polling state from apiInteractions.js
   - [ ] Migrate file selection state from main.js and fileSelection.js
   - [ ] Add state change listeners

3. **Day 4: PollingManager**
   - [ ] Create `pollingManager.js` with deduplication
   - [ ] Replace polling logic in apiInteractions.js
   - [ ] Add max retries and exponential backoff
   - [ ] Store timeout handles for proper cleanup

4. **Day 5: Integration & Testing**
   - [ ] Test multiple job submissions (no timer conflicts)
   - [ ] Test page navigation (all resources cleaned up)
   - [ ] Test file extraction (no blob leaks)
   - [ ] Monitor memory usage in DevTools
   - [ ] Verify no duplicate polling

---

## Testing Strategy

### Memory Leak Testing
```javascript
// 1. Open Chrome DevTools → Memory tab
// 2. Take heap snapshot
// 3. Extract 10 files (creates Blob URLs)
// 4. Take another heap snapshot
// 5. Compare: Should see Blob objects released

// Before fix: 10 Blob URLs leaked (500MB+)
// After fix: 0 Blob URLs leaked
```

### Countdown Testing
```javascript
// Test multiple job submissions
await submitJob();  // Starts countdown
await submitJob();  // Should NOT create second countdown

// Countdown should only show one timer
// No console errors about multiple intervals
```

### Polling Testing
```javascript
// Test duplicate polling prevention
pollingManager.start('job-123', ...);
pollingManager.start('job-123', ...);  // Should warn and return same stop function

// Test cleanup
const stop = pollingManager.start('job-123', ...);
stop();  // Should completely stop, no more requests

// Test max retries
// Simulate network failure
// After 10 retries, polling should stop automatically
```

---

## Success Criteria

- [ ] Zero Blob URL memory leaks (verify in heap snapshot)
- [ ] Single countdown instance only
- [ ] No duplicate polling for same job
- [ ] All timers/intervals cleaned up on page unload
- [ ] State changes are logged and traceable
- [ ] No race conditions in job status updates
- [ ] Memory usage stays constant over time (no gradual increase)

---

## Related Issues

- **002-ERROR-HANDLING.md** - Timer cleanup errors relate to error handling
- **005-API-NETWORKING.md** - Polling logic relates to API retry strategies
- **006-PERFORMANCE.md** - Memory leaks affect performance

---

**Created:** 2025-10-01
**Last Updated:** 2025-10-01
