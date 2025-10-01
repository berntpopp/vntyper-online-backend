# Architecture Refactoring & SOLID Principles

**Priority:** 🟡 **MEDIUM**
**Effort:** 2 weeks (major refactor)
**Status:** Open

---

## Executive Summary

**main.js is a 699-line God Object** that violates all SOLID principles. It handles initialization, file management, job submission, cohort creation, UI updates, BAM processing, and URL routing. This creates a maintenance nightmare and makes testing impossible.

**Violations:**
- **Single Responsibility** - main.js does everything
- **Open/Closed** - Adding features requires modifying main.js
- **Liskov Substitution** - No abstractions or interfaces
- **Interface Segregation** - Massive monolithic functions
- **Dependency Inversion** - Hard-coded dependencies everywhere

---

## Current Architecture Problems

### 1. God Object Anti-Pattern (main.js: 699 lines)

```javascript
// main.js structure:
async function initializeApp() {
    // Lines 59-99: Initialization (40 lines)
    // Lines 100-128: Reset state function (28 lines)
    // Lines 136-204: URL parameter handling (68 lines)
    // Lines 234-446: Job submission handler (212 lines!)
    // Lines 448-668: BAM extraction handler (220 lines!!)
    //... continue
}
```

**Single function handles:**
- Modal/footer/FAQ/tutorial initialization
- File validation
- Cohort creation
- Job submission
- Polling coordination
- UI updates
- BAM processing with Aioli
- Download link generation
- Error handling

### 2. Mixed Concerns Throughout

**main.js mixes:**
- Business logic (job submission)
- UI updates (DOM manipulation)
- API calls (cohort creation)
- File processing (BAM extraction)
- State management (displayedCohorts Set)
- Routing (URL parameters)

**Example (lines 234-272):**
```javascript
submitBtn.addEventListener('click', async () => {
    // Validation
    if (selectedFiles.length === 0) { /*...*/ }

    // UI update
    jobOutputDiv.innerHTML = '';
    showSpinner();

    // Business logic
    const CLI = await initializeAioli();
    const { matchedPairs } = validateFiles(selectedFiles);

    // State management
    const email = emailInput.value.trim();
    let cohortId = null;

    // More UI
    displayError(...);

    // API call
    const cohortData = await createCohort(...);

    // DOM manipulation
    const cohortSection = document.createElement('div');

    // ... 200 more lines of mixed concerns!
});
```

### 3. No Dependency Injection

**Hard-coded dependencies everywhere:**

```javascript
import { submitJobToAPI } from './apiInteractions.js';
import { initializeAioli } from './bamProcessing.js';
import { displayError } from './errorHandling.js';
// ... 20 more imports

// Used directly in functions - no injection, no mocking possible
const result = await submitJobToAPI(formData);
```

**Makes testing impossible** - can't mock dependencies.

### 4. Tight Coupling

```javascript
// jobManager.js depends on uiUtils.js
import { hideSpinner, clearCountdown } from './uiUtils.js';

// uiUtils.js depends on log.js
import { logMessage } from './log.js';

// apiInteractions.js depends on log.js
import { logMessage } from './log.js';

// Everything depends on everything!
```

**Circular dependency risks** and **hard to change** without breaking everything.

---

## Proposed Architecture

### Target: Controller-Based Architecture

```
app/
├── controllers/
│   ├── AppController.js          # Main app lifecycle
│   ├── JobController.js           # Job submission & tracking
│   ├── CohortController.js        # Cohort management
│   ├── FileController.js          # File selection & validation
│   └── ExtractionController.js    # BAM extraction
├── services/
│   ├── APIService.js              # HTTP requests
│   ├── BlobService.js             # Blob URL management
│   ├── PollingService.js          # Status polling
│   └── StateService.js            # State management
├── models/
│   ├── Job.js                     # Job model
│   ├── Cohort.js                  # Cohort model
│   └── File.js                    # File model
├── views/
│   ├── JobView.js                 # Job UI rendering
│   ├── CohortView.js              # Cohort UI rendering
│   └── ErrorView.js               # Error UI rendering
└── utils/
    ├── EventBus.js                # Event system
    ├── DI.js                      # Dependency injection
    └── Logger.js                  # Logging
```

### Example Controller Pattern

```javascript
// controllers/JobController.js

export class JobController {
    constructor(dependencies) {
        this.apiService = dependencies.apiService;
        this.stateService = dependencies.stateService;
        this.jobView = dependencies.jobView;
        this.errorView = dependencies.errorView;
        this.eventBus = dependencies.eventBus;

        this.bindEvents();
    }

    bindEvents() {
        this.eventBus.on('job:submit', this.handleSubmit.bind(this));
        this.eventBus.on('job:poll', this.handlePoll.bind(this));
    }

    async handleSubmit(files, options) {
        try {
            // Validation
            const validFiles = this.validateFiles(files);

            // Business logic
            const jobId = await this.apiService.submitJob(validFiles, options);

            // Update state
            this.stateService.addJob(jobId, { status: 'pending', files });

            // Update view
            this.jobView.showJob(jobId);

            // Start polling
            this.eventBus.emit('job:poll', jobId);

        } catch (error) {
            this.errorView.show(error.message);
        }
    }

    async handlePoll(jobId) {
        const stopPolling = await this.apiService.pollJobStatus(
            jobId,
            (status) => {
                this.stateService.updateJobStatus(jobId, status);
                this.jobView.updateStatus(jobId, status);
            },
            () => {
                this.jobView.showDownloadLink(jobId);
            }
        );

        this.stateService.setJobPolling(jobId, stopPolling);
    }

    validateFiles(files) {
        // Validation logic
        return files;
    }
}
```

---

## Implementation Steps

### Phase 1: Foundation (Days 1-3)
- [ ] Create EventBus for loose coupling
- [ ] Create DI container
- [ ] Extract StateService from scattered state
- [ ] Create base Controller class

### Phase 2: Extract Controllers (Days 4-8)
- [ ] Create JobController (extract from main.js:234-446)
- [ ] Create CohortController (extract cohort logic)
- [ ] Create FileController (extract file handling)
- [ ] Create ExtractionController (extract BAM processing)

### Phase 3: Extract Services (Days 9-11)
- [ ] APIService (wrap apiInteractions.js)
- [ ] PollingService (extract polling logic)
- [ ] BlobService (from state management issue)

### Phase 4: Views (Days 12-13)
- [ ] Extract DOM manipulation to View classes
- [ ] Create JobView, CohortView, ErrorView

### Phase 5: Integration & Testing (Day 14)
- [ ] Wire everything together
- [ ] Test all flows
- [ ] Verify no regressions

---

## Benefits

- **Testable** - Can mock dependencies, test controllers in isolation
- **Maintainable** - Each file has single responsibility
- **Extensible** - Add new features without modifying existing code
- **Debuggable** - Clear separation of concerns
- **Reusable** - Controllers/services can be reused

---

## Success Criteria

- [ ] main.js reduced to < 100 lines (just initialization)
- [ ] Each controller < 200 lines
- [ ] Unit tests for all controllers (80%+ coverage)
- [ ] No circular dependencies
- [ ] Clear separation: Controller → Service → View

---

**Created:** 2025-10-01
**Last Updated:** 2025-10-01
