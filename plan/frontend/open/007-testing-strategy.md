# Testing Strategy - Updated for v0.40.0

**Priority:** 🟡 **MEDIUM**
**Effort:** 2-3 weeks (initial setup + critical tests)
**Status:** Ready for Implementation
**Last Updated:** 2025-10-02
**Codebase Version:** v0.40.0 (Post-SOLID Refactor + Performance Optimizations)

---

## Executive Summary

**UPDATED FOR CURRENT SOLID ARCHITECTURE**

The frontend has **zero test coverage (0%)** but is now in an ideal state for testing after the v0.38.0 SOLID refactor. The modular architecture with controllers, services, views, and models provides clear boundaries for unit and integration testing.

**Current Codebase Statistics:**
- 44 JavaScript files
- 6 directories (controllers, models, services, utils, views, root)
- SOLID principles implemented
- Dependency injection in place
- Event-driven architecture

**Target Coverage:** 60-80% (prioritize critical paths)

---

## Architecture Analysis (v0.40.0)

### Current File Structure
```
resources/js/
├── controllers/          # 6 files - Application logic, event coordination
│   ├── AppController.js
│   ├── BaseController.js
│   ├── CohortController.js
│   ├── ExtractionController.js
│   ├── FileController.js
│   └── JobController.js
├── models/              # 2 files - Data models
│   ├── Cohort.js
│   └── Job.js
├── services/            # 2 files - API communication, HTTP utilities
│   ├── APIService.js
│   └── httpUtils.js
├── utils/               # 2 files - Core infrastructure
│   ├── DI.js           # Dependency injection container
│   └── EventBus.js     # Event pub/sub system
├── views/               # 3 files - UI rendering (no business logic)
│   ├── CohortView.js
│   ├── ErrorView.js
│   └── JobView.js
├── [core modules]/      # 29 files - Utilities, UI, validation
│   ├── stateManager.js
│   ├── pollingManager.js
│   ├── errorHandling.js
│   ├── validators.js
│   ├── inputWrangling.js
│   ├── bamProcessing.js
│   ├── blobManager.js
│   ├── domHelpers.js
│   └── ... (20 more UI/utility modules)
└── main.js             # Application bootstrap
```

### Testing Priorities by Architecture Layer

#### 🔴 **CRITICAL (Must Test First - Week 1)**
These modules contain core business logic and have high complexity:

1. **Controllers** (6 files)
   - Complex async workflows
   - Event coordination
   - State management
   - Error handling
   - **Why critical:** Main application logic, handles user interactions

2. **Services** (2 files)
   - API communication
   - HTTP retry logic
   - Timeout handling
   - **Why critical:** External dependencies, network failures

3. **Core Utilities** (5 files)
   - `stateManager.js` - Application state
   - `pollingManager.js` - Job status polling
   - `EventBus.js` - Event system
   - `DI.js` - Dependency injection
   - `errorHandling.js` - Error management
   - **Why critical:** Used throughout application

#### 🟡 **HIGH (Week 2)**
Important business logic with medium complexity:

4. **Models** (2 files)
   - `Job.js` - Job state, validation
   - `Cohort.js` - Cohort grouping
   - **Why high:** Data integrity, validation logic

5. **Validation & Processing** (3 files)
   - `validators.js` - Input validation
   - `inputWrangling.js` - File pair matching
   - `blobManager.js` - File blob management
   - **Why high:** Data validation, file handling

6. **BAM Processing** (1 file)
   - `bamProcessing.js` - WebAssembly, Aioli
   - **Why high:** Complex, async, external dependencies

#### 🟢 **MEDIUM (Week 3)**
Lower risk, mostly UI coordination:

7. **Views** (3 files)
   - DOM manipulation
   - UI rendering
   - **Why medium:** No business logic, easy to test manually

8. **UI Utilities** (20 files)
   - Modal, footer, FAQ, tutorial, etc.
   - **Why medium:** Simple, low risk, manual testing sufficient

---

## Testing Stack (2025 Best Practices)

### ✅ **Vitest** - Primary Testing Framework

**Why Vitest?**
- ✅ **Native ES Modules** - No transpilation needed
- ✅ **Fast** - Powered by Vite, instant hot reload
- ✅ **Compatible** - Jest-like API (easy migration path)
- ✅ **Modern** - Built for 2025, actively maintained
- ✅ **Browser Mode** - Test in real browsers (not just jsdom)
- ✅ **TypeScript** - First-class support (if we add types later)

### Installation

```bash
npm init -y  # Create package.json if it doesn't exist
npm install -D vitest @vitest/ui @vitest/browser happy-dom
npm install -D playwright  # For browser mode provider
```

### Configuration

**File:** `vitest.config.js`
```javascript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Use happy-dom for fast DOM simulation (alternative: jsdom)
    environment: 'happy-dom',

    // Global test APIs (describe, it, expect available everywhere)
    globals: true,

    // Coverage configuration
    coverage: {
      provider: 'v8',  // Fast, native coverage
      reporter: ['text', 'json', 'html'],
      include: ['resources/js/**/*.js'],
      exclude: [
        'resources/js/main.js',  // Bootstrap file
        'resources/js/**/*.test.js',
        'resources/js/**/*.spec.js',
        'resources/js/tutorial.js',  // UI-only modules
        'resources/js/modal.js',
        'resources/js/footer.js',
        'resources/js/faq.js',
        'resources/js/disclaimer.js',
        'resources/js/userGuide.js',
        'resources/js/citations.js',
      ],
      // Target: 60-80% coverage
      thresholds: {
        lines: 60,
        functions: 60,
        branches: 60,
        statements: 60
      }
    },

    // Test file patterns
    include: ['**/*.{test,spec}.{js,mjs,cjs}'],

    // Watch mode excludes
    watchExclude: ['**/node_modules/**', '**/dist/**'],
  },
})
```

### Browser Mode Configuration (Optional, for integration tests)

**File:** `vitest.workspace.js`
```javascript
import { defineWorkspace } from 'vitest/config'

export default defineWorkspace([
  // Unit tests with happy-dom
  {
    test: {
      name: 'unit',
      environment: 'happy-dom',
      include: ['tests/unit/**/*.test.js']
    }
  },
  // Integration tests with real browser
  {
    test: {
      name: 'browser',
      browser: {
        enabled: true,
        name: 'chromium',
        provider: 'playwright',
        headless: true
      },
      include: ['tests/integration/**/*.test.js']
    }
  }
])
```

---

## Test Structure

```
frontend/
├── tests/
│   ├── unit/                          # Fast, isolated tests
│   │   ├── controllers/
│   │   │   ├── BaseController.test.js
│   │   │   ├── JobController.test.js
│   │   │   ├── CohortController.test.js
│   │   │   ├── FileController.test.js
│   │   │   └── ExtractionController.test.js
│   │   ├── models/
│   │   │   ├── Job.test.js
│   │   │   └── Cohort.test.js
│   │   ├── services/
│   │   │   ├── APIService.test.js
│   │   │   └── httpUtils.test.js
│   │   ├── utils/
│   │   │   ├── EventBus.test.js
│   │   │   ├── DI.test.js
│   │   │   ├── stateManager.test.js
│   │   │   └── pollingManager.test.js
│   │   ├── core/
│   │   │   ├── errorHandling.test.js
│   │   │   ├── validators.test.js
│   │   │   ├── inputWrangling.test.js
│   │   │   └── blobManager.test.js
│   │   └── fixtures/
│   │       ├── mockControllers.js
│   │       ├── mockAPIResponses.js
│   │       └── testFiles.js
│   ├── integration/                   # Multi-component workflows
│   │   ├── jobSubmission.test.js     # File selection → extraction → submission
│   │   ├── cohortFlow.test.js        # Cohort creation → job grouping
│   │   ├── polling.test.js           # Status polling → UI updates
│   │   └── errorRecovery.test.js     # Network failures → retry logic
│   └── e2e/                           # Full user workflows (optional, Week 3+)
│       ├── jobSubmission.spec.js
│       ├── bamExtraction.spec.js
│       └── cohortAnalysis.spec.js
├── vitest.config.js
├── vitest.workspace.js (optional)
└── package.json
```

---

## Priority Tests - Week 1 (Critical Path)

### Day 1: Infrastructure Setup

#### 1. EventBus Tests (`tests/unit/utils/EventBus.test.js`)

**Why first:** Core infrastructure used by all controllers

```javascript
import { describe, it, expect, beforeEach } from 'vitest'
import { EventBus } from '../../../resources/js/utils/EventBus.js'

describe('EventBus', () => {
  let eventBus

  beforeEach(() => {
    eventBus = new EventBus()
  })

  describe('on() - Subscribe to events', () => {
    it('should call handler when event is emitted', () => {
      const handler = vi.fn()
      eventBus.on('test:event', handler)

      eventBus.emit('test:event', { data: 'test' })

      expect(handler).toHaveBeenCalledOnce()
      expect(handler).toHaveBeenCalledWith({ data: 'test' })
    })

    it('should support multiple handlers for same event', () => {
      const handler1 = vi.fn()
      const handler2 = vi.fn()
      eventBus.on('test:event', handler1)
      eventBus.on('test:event', handler2)

      eventBus.emit('test:event')

      expect(handler1).toHaveBeenCalledOnce()
      expect(handler2).toHaveBeenCalledOnce()
    })

    it('should return unsubscribe function', () => {
      const handler = vi.fn()
      const unsubscribe = eventBus.on('test:event', handler)

      unsubscribe()
      eventBus.emit('test:event')

      expect(handler).not.toHaveBeenCalled()
    })
  })

  describe('once() - One-time subscription', () => {
    it('should call handler only once', () => {
      const handler = vi.fn()
      eventBus.once('test:event', handler)

      eventBus.emit('test:event')
      eventBus.emit('test:event')

      expect(handler).toHaveBeenCalledOnce()
    })
  })

  describe('emit() - Publish events', () => {
    it('should return number of listeners notified', () => {
      eventBus.on('test:event', () => {})
      eventBus.on('test:event', () => {})

      const count = eventBus.emit('test:event')

      expect(count).toBe(2)
    })

    it('should return 0 when no listeners', () => {
      const count = eventBus.emit('test:event')

      expect(count).toBe(0)
    })
  })

  describe('off() - Unsubscribe', () => {
    it('should remove specific handler', () => {
      const handler = vi.fn()
      eventBus.on('test:event', handler)

      eventBus.off('test:event', handler)
      eventBus.emit('test:event')

      expect(handler).not.toHaveBeenCalled()
    })

    it('should remove all handlers for event when handler not specified', () => {
      const handler1 = vi.fn()
      const handler2 = vi.fn()
      eventBus.on('test:event', handler1)
      eventBus.on('test:event', handler2)

      eventBus.off('test:event')
      eventBus.emit('test:event')

      expect(handler1).not.toHaveBeenCalled()
      expect(handler2).not.toHaveBeenCalled()
    })
  })
})
```

**Coverage Target:** 100% (core infrastructure must be rock solid)

#### 2. StateManager Tests (`tests/unit/utils/stateManager.test.js`)

```javascript
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { stateManager } from '../../../resources/js/stateManager.js'

describe('StateManager', () => {
  beforeEach(() => {
    // Reset state before each test
    stateManager.reset()
  })

  describe('get() / set()', () => {
    it('should set and get values', () => {
      stateManager.set('test.key', 'value')

      expect(stateManager.get('test.key')).toBe('value')
    })

    it('should support nested paths', () => {
      stateManager.set('user.profile.name', 'Alice')

      expect(stateManager.get('user.profile.name')).toBe('Alice')
      expect(stateManager.get('user.profile')).toEqual({ name: 'Alice' })
    })

    it('should return undefined for non-existent keys', () => {
      expect(stateManager.get('nonexistent')).toBeUndefined()
    })
  })

  describe('Job management', () => {
    it('should add job with ID', () => {
      stateManager.addJob('job-123', {
        status: 'pending',
        fileName: 'test.bam'
      })

      const job = stateManager.getJob('job-123')
      expect(job).toEqual({
        status: 'pending',
        fileName: 'test.bam'
      })
    })

    it('should update job status', () => {
      stateManager.addJob('job-123', { status: 'pending' })

      stateManager.updateJobStatus('job-123', 'completed')

      expect(stateManager.getJob('job-123').status).toBe('completed')
    })

    it('should get all jobs', () => {
      stateManager.addJob('job-1', { status: 'pending' })
      stateManager.addJob('job-2', { status: 'completed' })

      const jobs = stateManager.getJobs()
      expect(jobs).toHaveLength(2)
    })
  })

  describe('Cohort management', () => {
    it('should add cohort', () => {
      stateManager.addCohort('cohort-123', {
        alias: 'Test Cohort',
        jobIds: []
      })

      const cohort = stateManager.getCohort('cohort-123')
      expect(cohort.alias).toBe('Test Cohort')
    })

    it('should add job to cohort', () => {
      stateManager.addCohort('cohort-123', { jobIds: [] })

      stateManager.addJobToCohort('cohort-123', 'job-1')
      stateManager.addJobToCohort('cohort-123', 'job-2')

      const cohort = stateManager.getCohort('cohort-123')
      expect(cohort.jobIds).toEqual(['job-1', 'job-2'])
    })

    it('should check if all cohort jobs are complete', () => {
      stateManager.addCohort('cohort-123', { jobIds: ['job-1', 'job-2'] })
      stateManager.addJob('job-1', { status: 'completed' })
      stateManager.addJob('job-2', { status: 'pending' })

      expect(stateManager.areCohortJobsComplete('cohort-123')).toBe(false)

      stateManager.updateJobStatus('job-2', 'completed')
      expect(stateManager.areCohortJobsComplete('cohort-123')).toBe(true)
    })
  })
})
```

**Coverage Target:** 95%+ (critical state management)

### Day 2-3: Service Layer Tests

#### 3. httpUtils Tests (`tests/unit/services/httpUtils.test.js`)

```javascript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { fetchWithTimeout, fetchWithRetry } from '../../../resources/js/services/httpUtils.js'

describe('httpUtils', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    global.fetch = vi.fn()
  })

  afterEach(() => {
    vi.restoreAllMocks()
    vi.useRealTimers()
  })

  describe('fetchWithTimeout()', () => {
    it('should resolve when fetch completes before timeout', async () => {
      const mockResponse = { ok: true, json: async () => ({ data: 'test' }) }
      global.fetch.mockResolvedValueOnce(mockResponse)

      const promise = fetchWithTimeout('https://api.test.com', {}, 5000)
      await vi.runAllTimersAsync()

      const result = await promise
      expect(result).toEqual(mockResponse)
    })

    it('should reject with timeout error when fetch takes too long', async () => {
      global.fetch.mockImplementation(() =>
        new Promise(resolve => setTimeout(resolve, 10000))
      )

      const promise = fetchWithTimeout('https://api.test.com', {}, 1000)

      await expect(promise).rejects.toThrow('Request timeout')
    })

    it('should clean up timeout on successful fetch', async () => {
      const clearTimeoutSpy = vi.spyOn(global, 'clearTimeout')
      global.fetch.mockResolvedValueOnce({ ok: true })

      await fetchWithTimeout('https://api.test.com', {}, 5000)

      expect(clearTimeoutSpy).toHaveBeenCalled()
    })
  })

  describe('fetchWithRetry()', () => {
    it('should succeed on first try', async () => {
      const mockResponse = { ok: true, json: async () => ({ success: true }) }
      global.fetch.mockResolvedValueOnce(mockResponse)

      const result = await fetchWithRetry('https://api.test.com', {}, 3, 1000)

      expect(global.fetch).toHaveBeenCalledOnce()
      expect(result).toEqual(mockResponse)
    })

    it('should retry on network error', async () => {
      global.fetch
        .mockRejectedValueOnce(new Error('Network error'))
        .mockRejectedValueOnce(new Error('Network error'))
        .mockResolvedValueOnce({ ok: true })

      const result = await fetchWithRetry('https://api.test.com', {}, 3, 100)

      expect(global.fetch).toHaveBeenCalledTimes(3)
      expect(result).toEqual({ ok: true })
    })

    it('should throw after max retries', async () => {
      global.fetch.mockRejectedValue(new Error('Network error'))

      await expect(
        fetchWithRetry('https://api.test.com', {}, 3, 100)
      ).rejects.toThrow('Network error')

      expect(global.fetch).toHaveBeenCalledTimes(3)
    })

    it('should respect retry delay', async () => {
      global.fetch
        .mockRejectedValueOnce(new Error('Network error'))
        .mockResolvedValueOnce({ ok: true })

      const start = Date.now()
      await fetchWithRetry('https://api.test.com', {}, 3, 1000)
      const elapsed = Date.now() - start

      expect(elapsed).toBeGreaterThanOrEqual(1000)
    })
  })
})
```

**Coverage Target:** 95%+ (HTTP layer is critical)

### Day 4-5: Controller Tests

#### 4. BaseController Tests (`tests/unit/controllers/BaseController.test.js`)

```javascript
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { BaseController } from '../../../resources/js/controllers/BaseController.js'
import { EventBus } from '../../../resources/js/utils/EventBus.js'

class TestController extends BaseController {
  bindEvents() {
    this.on('test:event', this.handleTestEvent)
  }

  handleTestEvent(data) {
    this.testEventCalled = true
    this.testEventData = data
  }
}

describe('BaseController', () => {
  let eventBus
  let stateManager
  let logger

  beforeEach(() => {
    eventBus = new EventBus()
    stateManager = { get: vi.fn(), set: vi.fn() }
    logger = { logMessage: vi.fn() }
  })

  describe('constructor()', () => {
    it('should require dependencies object', () => {
      expect(() => new BaseController()).toThrow('dependencies object is required')
    })

    it('should require eventBus dependency', () => {
      expect(() => new BaseController({})).toThrow('eventBus dependency is required')
    })

    it('should require stateManager dependency', () => {
      expect(() => new BaseController({ eventBus })).toThrow('stateManager dependency is required')
    })

    it('should initialize with valid dependencies', () => {
      const controller = new BaseController({ eventBus, stateManager, logger })

      expect(controller.eventBus).toBe(eventBus)
      expect(controller.stateManager).toBe(stateManager)
      expect(controller.logger).toBe(logger)
      expect(controller.isInitialized).toBe(true)
    })
  })

  describe('on() - Event subscription', () => {
    it('should subscribe to events', () => {
      const controller = new TestController({ eventBus, stateManager, logger })
      const handler = vi.fn()

      controller.on('custom:event', handler)
      eventBus.emit('custom:event', { data: 'test' })

      expect(handler).toHaveBeenCalledWith({ data: 'test' })
    })

    it('should bind handler to controller context', () => {
      const controller = new TestController({ eventBus, stateManager, logger })

      eventBus.emit('test:event', { value: 42 })

      expect(controller.testEventCalled).toBe(true)
      expect(controller.testEventData).toEqual({ value: 42 })
    })

    it('should track subscriptions for cleanup', () => {
      const controller = new TestController({ eventBus, stateManager, logger })

      expect(controller.eventSubscriptions.length).toBeGreaterThan(0)
    })
  })

  describe('emit() - Event publishing', () => {
    it('should emit events via eventBus', () => {
      const controller = new TestController({ eventBus, stateManager, logger })
      const handler = vi.fn()
      eventBus.on('controller:action', handler)

      controller.emit('controller:action', { result: 'success' })

      expect(handler).toHaveBeenCalledWith({ result: 'success' })
    })
  })

  describe('handleError()', () => {
    it('should log error with context', () => {
      const controller = new TestController({ eventBus, stateManager, logger })
      const error = new Error('Test error')

      controller.handleError(error, 'Test context')

      expect(logger.logMessage).toHaveBeenCalledWith(
        expect.stringContaining('Test context: Test error'),
        'error'
      )
    })

    it('should emit error event', () => {
      const controller = new TestController({ eventBus, stateManager, logger })
      const errorHandler = vi.fn()
      eventBus.on('error', errorHandler)

      const error = new Error('Test error')
      controller.handleError(error, 'Test context')

      expect(errorHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          controller: 'TestController',
          context: 'Test context',
          error
        })
      )
    })
  })

  describe('destroy()', () => {
    it('should unsubscribe from all events', () => {
      const controller = new TestController({ eventBus, stateManager, logger })
      const handler = vi.fn()
      eventBus.on('test:event', handler)

      controller.destroy()
      eventBus.emit('test:event')

      expect(handler).not.toHaveBeenCalled()
    })

    it('should set isDestroyed flag', () => {
      const controller = new TestController({ eventBus, stateManager, logger })

      controller.destroy()

      expect(controller.isDestroyed).toBe(true)
      expect(controller.isInitialized).toBe(false)
    })

    it('should prevent double destruction', () => {
      const controller = new TestController({ eventBus, stateManager, logger })

      controller.destroy()
      controller.destroy()

      expect(logger.logMessage).toHaveBeenCalledWith(
        expect.stringContaining('Already destroyed'),
        'warning'
      )
    })
  })
})
```

**Coverage Target:** 100% (base class must be bulletproof)

---

## Integration Tests - Week 2

### Example: Job Submission Flow

**File:** `tests/integration/jobSubmission.test.js`

```javascript
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { JobController } from '../../resources/js/controllers/JobController.js'
import { FileController } from '../../resources/js/controllers/FileController.js'
import { ExtractionController } from '../../resources/js/controllers/ExtractionController.js'
import { EventBus } from '../../resources/js/utils/EventBus.js'
import { stateManager } from '../../resources/js/stateManager.js'

describe('Job Submission Integration', () => {
  let eventBus
  let fileController
  let extractionController
  let jobController
  let mockAPIService
  let mockJobView

  beforeEach(() => {
    eventBus = new EventBus()
    stateManager.reset()

    mockAPIService = {
      submitJob: vi.fn().mockResolvedValue({
        jobId: 'test-job-123',
        status: 'pending'
      })
    }

    mockJobView = {
      showJob: vi.fn(),
      updateStatus: vi.fn(),
      showDownloadLink: vi.fn()
    }

    // Create interconnected controllers
    const deps = {
      eventBus,
      stateManager,
      logger: console,
      apiService: mockAPIService,
      jobView: mockJobView,
      selectedFiles: []
    }

    fileController = new FileController(deps)
    extractionController = new ExtractionController(deps)
    jobController = new JobController(deps)
  })

  it('should complete full job submission workflow', async () => {
    // 1. File selection
    const testFile = new File(['test'], 'test.bam', { type: 'application/octet-stream' })
    fileController.emit('files:selected', { files: [testFile] })

    // 2. Extraction (mock)
    extractionController.emit('extraction:complete', {
      pair: { bam: testFile },
      subsetBamAndBaiBlobs: [{
        subsetBamBlob: new Blob(['test']),
        subsetBaiBlob: new Blob(['test']),
        subsetName: 'test_subset.bam'
      }],
      detectedAssembly: 'hg38',
      region: 'chr1:1-1000'
    })

    // 3. Job submission
    const formData = new FormData()
    formData.append('bam_file', new Blob(['test']), 'test.bam')

    await jobController.handleSubmit({
      formData,
      fileName: 'test.bam'
    })

    // Verify workflow
    expect(mockAPIService.submitJob).toHaveBeenCalledOnce()
    expect(mockJobView.showJob).toHaveBeenCalledWith(
      expect.objectContaining({
        jobId: 'test-job-123',
        status: 'pending'
      })
    )
    expect(stateManager.getJob('test-job-123')).toBeDefined()
  })
})
```

---

## package.json Scripts

```json
{
  "name": "vntyper-frontend",
  "version": "0.40.0",
  "type": "module",
  "scripts": {
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:watch": "vitest watch",
    "test:unit": "vitest run tests/unit",
    "test:integration": "vitest run tests/integration",
    "test:browser": "vitest run --browser.name=chromium tests/integration"
  },
  "devDependencies": {
    "@vitest/browser": "^3.0.0",
    "@vitest/ui": "^3.0.0",
    "happy-dom": "^15.0.0",
    "playwright": "^1.47.0",
    "vitest": "^3.0.0"
  }
}
```

---

## Implementation Timeline

### Week 1: Critical Path (40 hours)
- **Day 1** (8h): Setup + EventBus + StateManager tests
- **Day 2** (8h): httpUtils + APIService tests
- **Day 3** (8h): BaseController tests
- **Day 4** (8h): JobController + FileController tests
- **Day 5** (8h): CohortController + ExtractionController tests

**Deliverable:** ~60% code coverage on critical modules

### Week 2: High Priority (32 hours)
- **Day 1-2** (16h): Model tests (Job, Cohort)
- **Day 3** (8h): Validation tests (validators, inputWrangling)
- **Day 4-5** (8h): Integration tests (job submission, cohort flow, polling)

**Deliverable:** ~70% code coverage, all critical paths tested

### Week 3: Medium Priority (Optional, 24 hours)
- **Day 1-2** (16h): View tests (JobView, CohortView, ErrorView)
- **Day 3** (8h): E2E tests setup + first test

**Deliverable:** 80%+ coverage, E2E foundation

---

## Success Criteria

### Must Have (Week 1-2)
- [x] Vitest configured and running
- [x] 60%+ code coverage
- [x] All controllers tested
- [x] All services tested
- [x] Core utilities tested (EventBus, StateManager, DI)
- [x] Integration tests for critical workflows

### Should Have (Week 3)
- [ ] 70%+ code coverage
- [ ] Model tests
- [ ] Validation tests
- [ ] View tests

### Nice to Have (Future)
- [ ] 80%+ code coverage
- [ ] E2E tests with Playwright
- [ ] Visual regression tests
- [ ] Performance benchmarks

---

## CI/CD Integration

**File:** `.github/workflows/frontend-tests.yml`

```yaml
name: Frontend Tests

on:
  push:
    branches: [main, develop]
    paths:
      - 'frontend/**'
  pull_request:
    branches: [main]
    paths:
      - 'frontend/**'

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        working-directory: frontend
        run: npm ci

      - name: Run unit tests
        working-directory: frontend
        run: npm run test:unit

      - name: Run integration tests
        working-directory: frontend
        run: npm run test:integration

      - name: Generate coverage report
        working-directory: frontend
        run: npm run test:coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./frontend/coverage/coverage-final.json
          flags: frontend
          name: frontend-coverage

      - name: Comment coverage on PR
        if: github.event_name == 'pull_request'
        uses: romeovs/lcov-reporter-action@v0.3.1
        with:
          lcov-file: ./frontend/coverage/lcov.info
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

---

## Best Practices (2025)

### ✅ DO
- **Use Vitest** - Modern, fast, ES modules native
- **Use happy-dom** - Faster than jsdom for most cases
- **Mock at service boundary** - Mock APIService, not fetch
- **Test behavior, not implementation** - Test what users see
- **Use fixtures** - Reusable test data
- **Async/await** - Modern async handling
- **Coverage thresholds** - Enforce minimum coverage

### ❌ DON'T
- **Don't use Jest** - Not optimized for ES modules
- **Don't test views extensively** - Low value, high maintenance
- **Don't mock everything** - Test real code paths when possible
- **Don't aim for 100% coverage** - Diminishing returns after 80%
- **Don't test UI modules** - Manual testing sufficient

---

## Follow SOLID Principles in Tests

### Single Responsibility
```javascript
// ✅ Good - One test, one assertion
it('should add job to state', () => {
  stateManager.addJob('job-1', { status: 'pending' })
  expect(stateManager.getJob('job-1')).toBeDefined()
})

// ❌ Bad - Multiple unrelated assertions
it('should handle jobs and cohorts', () => {
  stateManager.addJob('job-1', {})
  stateManager.addCohort('cohort-1', {})
  expect(stateManager.getJob('job-1')).toBeDefined()
  expect(stateManager.getCohort('cohort-1')).toBeDefined()
})
```

### DRY
```javascript
// ✅ Good - Reusable fixtures
import { createMockJob, createMockCohort } from './fixtures/mockData.js'

// ❌ Bad - Duplicate test data
const mockJob = { id: 'job-1', status: 'pending', ... }
```

### Dependency Inversion
```javascript
// ✅ Good - Mock dependencies
const mockAPIService = { submitJob: vi.fn() }
const controller = new JobController({ apiService: mockAPIService })

// ❌ Bad - Test real API
const controller = new JobController({ apiService: new APIService() })
```

---

**Created:** 2025-10-02 (Updated from original 2025-10-01 plan)
**Status:** ✅ READY FOR IMPLEMENTATION
**Next Action:** Install Vitest and create first test (EventBus.test.js)
