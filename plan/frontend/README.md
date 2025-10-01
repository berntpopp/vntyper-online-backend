# Frontend Refactoring Plan

**Component:** Static HTML/JavaScript Application (Vanilla JS)
**Location:** `frontend/` (Git submodule)
**Submodule:** https://github.com/berntpopp/vntyper-online-frontend.git

---

## Executive Summary

The frontend codebase has **critical issues** in error handling, state management, and architecture that need systematic refactoring. This plan prioritizes issues by risk and provides detailed implementation guides.

**Overall Assessment:** C+ → Target: B+
- **Lines of Code:** ~4,300 JavaScript
- **Test Coverage:** 0% → Target: 60-80%
- **Code Duplication:** 15-20%
- **Architecture:** Monolithic → Target: Modular

---

## Open Issues (6)

### 🔴 Critical Priority

#### [002-ERROR-HANDLING.md](open/002-error-handling.md)
**Priority:** CRITICAL | **Effort:** 3-4 days

**Problems:**
- 13-line error handling module (crashes if DOM elements missing)
- 92 DOM queries with zero null checks
- No global error handler
- 59 try-catch blocks with inconsistent patterns
- Timer leaks in 5 files

**Impact:** Application crashes, poor UX, memory leaks

---

### 🟠 High Priority

#### [003-STATE-MANAGEMENT.md](open/003-state-management.md)
**Priority:** HIGH | **Effort:** 4-5 days

**Problems:**
- **CRITICAL:** Blob URL memory leak (main.js:612-652) - BAI URL never revoked
- Global countdown timer conflicts (creates multiple intervals)
- Polling race conditions (incomplete deduplication)
- State scattered across 6+ modules
- No lifecycle management

**Impact:** Memory leaks (~50-500MB per file extraction), timer conflicts, race conditions

---

### 🟡 Medium Priority

#### [004-ARCHITECTURE-SOLID.md](open/004-architecture-solid.md)
**Priority:** MEDIUM | **Effort:** 2 weeks ⚠️ MAJOR REFACTOR

**Problems:**
- **main.js is 699-line God Object** (violates all SOLID principles)
- Mixed concerns (business logic + UI + API + state)
- No dependency injection (impossible to test)
- Tight coupling throughout
- Hard to maintain and extend

**Impact:** Technical debt, impossible to test, hard to maintain

**⚠️ Recommendation:** Save for last - requires careful planning

---

#### [005-API-NETWORKING.md](open/005-api-networking.md)
**Priority:** MEDIUM | **Effort:** 3-4 days

**Problems:**
- No retry logic (fails immediately on network hiccup)
- No timeout handling (hangs forever on slow networks)
- No request cancellation (AbortController)
- Duplicate error parsing in 8 locations
- No request deduplication

**Impact:** Poor reliability, duplicate code, bad UX on slow connections

---

#### [006-PERFORMANCE.md](open/006-performance.md)
**Priority:** MEDIUM | **Effort:** 3-4 days

**Problems:**
- 92 DOM queries with zero caching (same elements queried repeatedly)
- All 25 modules loaded upfront (4,300 lines, no lazy loading)
- 28.9KB config.js with embedded base64 images (8 logos)
- 520-line bamProcessing.js loaded even if never used
- No debouncing on file selection (lags with 100+ files)

**Impact:** Slow page load (~5s on 3G), memory waste, UI lag

---

#### [007-TESTING-STRATEGY.md](open/007-testing-strategy.md)
**Priority:** MEDIUM | **Effort:** 1-2 weeks (ongoing)

**Problems:**
- **Zero test coverage (0%)**
- No testing infrastructure
- No unit/integration/E2E tests

**Target:** 60-80% coverage with Vitest + Playwright

---

## Completed Issues (1)

### ✅ [001-SECURITY-ISSUES](../completed/2025-09/frontend-001-security-xss.md)
**Completed:** 2025-09-30 | **Branch:** `refactor/security-xss-fixes`

- Fixed 16 XSS vulnerabilities (7 documented + 9 discovered)
- Created `domHelpers.js` with safe DOM API
- Created `validators.js` with input validation
- **All tests passing**

---

## Recommended Implementation Order

1. ✅ **Security** (001) - **COMPLETED**
2. 🔄 **Error Handling** (002) - **Next** (critical infrastructure)
3. 🔄 **State Management** (003) - Fixes memory leaks
4. 🔄 **API Networking** (005) - Improves reliability
5. 🔄 **Performance** (006) - Improves UX
6. 🔄 **Testing** (007) - Throughout all phases
7. 🔄 **Architecture** (004) - **Last** (major refactor, plan carefully!)

**Rationale:**
- Fix critical crashes first (002)
- Fix memory leaks second (003)
- Improve reliability third (005)
- Optimize performance fourth (006)
- Add tests throughout (007)
- Big refactor last when codebase is stable (004)

---

## Progress Overview

| Issue | Priority | Effort | Status | Completion |
|-------|----------|--------|--------|------------|
| 001. Security | 🔴 Critical | 1-2 days | ✅ Done | 100% |
| 002. Error Handling | 🔴 Critical | 3-4 days | 📋 Open | 0% |
| 003. State Management | 🟠 High | 4-5 days | 📋 Open | 0% |
| 004. Architecture | 🟡 Medium | 2 weeks | 📋 Open | 0% |
| 005. API Networking | 🟡 Medium | 3-4 days | 📋 Open | 0% |
| 006. Performance | 🟡 Medium | 3-4 days | 📋 Open | 0% |
| 007. Testing | 🟡 Medium | 1-2 weeks | 📋 Open | 0% |
| **TOTAL** | | **~6 weeks** | | **14.3%** |

---

## Code Quality Metrics

### Current State
- **Total Lines:** ~4,300 JavaScript
- **Largest File:** main.js (699 lines) - God Object
- **Test Coverage:** 0%
- **Try-Catch Blocks:** 59 (inconsistent patterns)
- **DOM Queries:** 92 (no caching)
- **Base64 in JS:** 28.9KB (config.js)
- **Memory Leaks:** Yes (Blob URLs, timers)
- **Code Duplication:** 15-20%

### Target State
- **Total Lines:** ~4,500 (refactored, more modular)
- **Largest File:** <200 lines (controllers)
- **Test Coverage:** 60-80%
- **Error Handling:** Centralized ErrorHandler class
- **DOM Queries:** 95%+ cached
- **Base64 in JS:** 0KB (external files)
- **Memory Leaks:** None
- **Code Duplication:** <5%

---

## Key Architectural Improvements

### Current Architecture
```
main.js (699 lines)
├── Initialization (40 lines)
├── Event handlers (400+ lines)
├── Business logic (mixed)
├── UI updates (mixed)
└── API calls (mixed)
```

### Target Architecture
```
app/
├── controllers/
│   ├── JobController.js
│   ├── CohortController.js
│   ├── FileController.js
│   └── ExtractionController.js
├── services/
│   ├── APIService.js
│   ├── StateService.js
│   ├── BlobService.js
│   └── PollingService.js
├── views/
│   ├── JobView.js
│   ├── CohortView.js
│   └── ErrorView.js
└── utils/
    ├── ErrorHandler.js
    ├── DOMCache.js
    ├── EventBus.js
    └── HTTPClient.js
```

---

## Getting Started

### For New Issues

1. **Read the issue document** in `open/` folder
2. **Create feature branch:** `frontend/NNN-short-description`
3. **Follow implementation steps** in the issue
4. **Write tests** as you go
5. **Update issue** with progress notes
6. **Move to done/** when completed

### For Continuing Work

1. **Check completed issues** in `done/` for patterns
2. **Follow established conventions** from completed work
3. **Reference line numbers** when discussing code
4. **Test thoroughly** before marking complete

---

## Testing Approach

### Unit Tests (Vitest)
```bash
npm install -D vitest @vitest/ui jsdom
npm test
```

### E2E Tests (Playwright)
```bash
npm install -D @playwright/test
npm run test:e2e
```

### Target Coverage
- **Critical paths:** 80%+
- **Utilities:** 90%+
- **Overall:** 60-80%

---

## Documentation Standards

### When Completing an Issue

1. Move file from `open/` to `done/`
2. Update status to ✅ COMPLETED with date
3. Add test results and verification steps
4. Document lessons learned
5. Update this README with progress

### When Starting an Issue

1. Review completed issues for patterns
2. Create feature branch
3. Reference issue number in commits
4. Update documentation as you progress

---

## Related Documentation

- **Main README:** [../../README.md](../../README.md)
- **CLAUDE.md:** [../../CLAUDE.md](../../CLAUDE.md) (architecture guide)
- **Completed Issues:** [done/](done/)
- **Code Review:** [cross-cutting/CODE_REVIEW.md](../cross-cutting/CODE_REVIEW.md)

---

**Last Updated:** 2025-10-01
**Next Review:** After completing Issue 002 (Error Handling)
