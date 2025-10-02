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

## Open Issues (13)

### 🔴 Critical Priority

#### [002-ERROR-HANDLING.md](open/002-error-handling.md)
**Priority:** CRITICAL | **Effort:** 3-4 days | **Category:** Architecture

**Problems:**
- 13-line error handling module (crashes if DOM elements missing)
- 92 DOM queries with zero null checks
- No global error handler
- 59 try-catch blocks with inconsistent patterns
- Timer leaks in 5 files

**Impact:** Application crashes, poor UX, memory leaks

---

#### [010-P0-COLOR-CONTRAST-COMPLIANCE.md](open/010-p0-color-contrast-compliance.md)
**Priority:** CRITICAL | **Effort:** 2-4 hours | **Category:** Accessibility (WCAG AA)

**Problems:**
- Orange button fails WCAG AA (2.3:1 contrast ratio)
- Download links borderline contrast (3:1)
- Cohort sections need verification
- Legal compliance risk

**Impact:** 10-15% of users affected, ADA/Section 508 compliance issues

---

#### [011-P0-FOCUS-INDICATOR-CONSISTENCY.md](open/011-p0-focus-indicator-consistency.md)
**Priority:** CRITICAL | **Effort:** 2-3 hours | **Category:** Accessibility (Keyboard Navigation)

**Problems:**
- Inconsistent focus indicators across components
- Missing skip-to-main-content link
- Modal focus trap not implemented
- Tooltip elements have focus disabled

**Impact:** 2-5% keyboard-only users cannot navigate effectively

---

#### [012-P0-LINK-DIFFERENTIATION-BODY-TEXT.md](open/012-p0-link-differentiation-body-text.md)
**Priority:** CRITICAL | **Effort:** 1-2 hours | **Category:** Accessibility (Color Blindness)

**Problems:**
- Links rely on color only (no underline)
- WCAG 1.4.1 violation (Use of Color - Level A)
- 8-10% of males have color blindness

**Impact:** Links invisible to color-blind users, WCAG Level A failure

---

### 🟠 High Priority

#### [003-STATE-MANAGEMENT.md](open/003-state-management.md)
**Priority:** HIGH | **Effort:** 4-5 days | **Category:** Architecture

**Problems:**
- **CRITICAL:** Blob URL memory leak (main.js:612-652) - BAI URL never revoked
- Global countdown timer conflicts (creates multiple intervals)
- Polling race conditions (incomplete deduplication)
- State scattered across 6+ modules
- No lifecycle management

**Impact:** Memory leaks (~50-500MB per file extraction), timer conflicts, race conditions

---

#### [013-P1-MOBILE-NAVIGATION-HAMBURGER-MENU.md](open/013-p1-mobile-navigation-hamburger-menu.md)
**Priority:** HIGH | **Effort:** 4-6 hours | **Category:** Mobile UX

**Problems:**
- Hamburger menu not functional (incomplete implementation)
- All nav items always visible on mobile (wastes space)
- Poor mobile experience (25-40% of users)
- Navigation takes 200-250px vertical space

**Impact:** High mobile bounce rate, poor first impression, difficult navigation

---

#### [014-P1-BUTTON-HIERARCHY-SIZING.md](open/014-p1-button-hierarchy-sizing.md)
**Priority:** HIGH | **Effort:** 3-4 hours | **Category:** Visual Hierarchy

**Problems:**
- All buttons same size (no visual hierarchy)
- Primary vs secondary actions unclear
- Decision paralysis for users

**Impact:** Unclear user flow, reduced conversion rates

---

#### [015-P1-TOUCH-TARGET-SIZING.md](open/015-p1-touch-target-sizing.md)
**Priority:** HIGH | **Effort:** 2-3 hours | **Category:** Mobile Accessibility

**Problems:**
- Reset button: ~20×20px (need 44×44px minimum)
- Remove file buttons: ~16×16px
- Modal close: ~24×24px
- WCAG 2.5.5 Level AAA violation

**Impact:** Mobile misclicks, user frustration, accessibility failure

---

#### [016-P1-ENHANCED-ERROR-STATES.md](open/016-p1-enhanced-error-states.md)
**Priority:** HIGH | **Effort:** 6-8 hours | **Category:** Form Validation

**Problems:**
- No inline validation
- Errors shown only after submission
- No helpful recovery guidance
- Poor form completion rates

**Impact:** User frustration, failed submissions, poor UX

---

### 🟡 Medium Priority

#### [004-ARCHITECTURE-SOLID.md](open/004-architecture-solid.md)
**Priority:** MEDIUM | **Effort:** 2 weeks ⚠️ MAJOR REFACTOR | **Category:** Architecture

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
**Priority:** MEDIUM | **Effort:** 3-4 days | **Category:** Architecture

**Problems:**
- No retry logic (fails immediately on network hiccup)
- No timeout handling (hangs forever on slow networks)
- No request cancellation (AbortController)
- Duplicate error parsing in 8 locations
- No request deduplication

**Impact:** Poor reliability, duplicate code, bad UX on slow connections

---

#### [006-PERFORMANCE.md](open/006-performance.md)
**Priority:** MEDIUM | **Effort:** 3-4 days | **Category:** Performance

**Problems:**
- 92 DOM queries with zero caching (same elements queried repeatedly)
- All 25 modules loaded upfront (4,300 lines, no lazy loading)
- 28.9KB config.js with embedded base64 images (8 logos)
- 520-line bamProcessing.js loaded even if never used
- No debouncing on file selection (lags with 100+ files)

**Impact:** Slow page load (~5s on 3G), memory waste, UI lag

---

#### [007-TESTING-STRATEGY.md](open/007-testing-strategy.md)
**Priority:** MEDIUM | **Effort:** 1-2 weeks (ongoing) | **Category:** Testing

**Problems:**
- **Zero test coverage (0%)**
- No testing infrastructure
- No unit/integration/E2E tests

**Target:** 60-80% coverage with Vitest + Playwright

---

## Completed Issues (2)

### ✅ [001-SECURITY-ISSUES](../completed/2025-09/frontend-001-security-xss.md)
**Completed:** 2025-09-30 | **Branch:** `refactor/security-xss-fixes`

- Fixed 16 XSS vulnerabilities (7 documented + 9 discovered)
- Created `domHelpers.js` with safe DOM API
- Created `validators.js` with input validation
- **All tests passing**

### ✅ [017-P1-LOGGING-ENHANCEMENTS](done/017-p1-logging-enhancements.md)
**Completed:** 2025-10-02 | **Branch:** `main` | **Version:** 0.41.0

- Added 5 log levels (debug, info, success, warning, error)
- Implemented log filtering with persistence (localStorage)
- Added download functionality (TXT/JSON formats)
- Added clear logs with confirmation
- Refactored log.js following SOLID principles (95 → 460 lines, fully modular)
- Custom tooltips matching navbar style (data-tooltip)
- WCAG AA compliant, touch-friendly (44×44px targets)
- **All functionality tested, no regressions**

---

## Recommended Implementation Order

### Phase 1: Accessibility Compliance (Week 1-2) - **HIGHEST PRIORITY**
1. 🔄 **Color Contrast** (010) - 2-4 hours - WCAG AA compliance
2. 🔄 **Focus Indicators** (011) - 2-3 hours - Keyboard navigation
3. 🔄 **Link Differentiation** (012) - 1-2 hours - Color blindness fix

**Rationale:** Legal compliance, affects 10-20% of users, quick wins

### Phase 2: Critical Infrastructure (Week 2-3)
4. ✅ **Security** (001) - **COMPLETED**
5. 🔄 **Error Handling** (002) - 3-4 days - Prevents crashes
6. 🔄 **State Management** (003) - 4-5 days - Fixes memory leaks

**Rationale:** Fix crashes and memory leaks before adding features

### Phase 3: Mobile & High-Priority UX (Week 4-5)
7. 🔄 **Mobile Navigation** (013) - 4-6 hours - 25-40% of users
8. 🔄 **Touch Target Sizing** (015) - 2-3 hours - Mobile accessibility
9. 🔄 **Button Hierarchy** (014) - 3-4 hours - Visual hierarchy
10. ✅ **Logging Enhancements** (017) - **COMPLETED** - Better debugging
11. 🔄 **Enhanced Error States** (016) - 6-8 hours - Form validation

**Rationale:** Mobile users are significant portion, improves conversion rates, better debugging tools

### Phase 4: Medium Priority (Month 2)
12. 🔄 **API Networking** (005) - 3-4 days - Improves reliability
13. 🔄 **Performance** (006) - 3-4 days - Improves UX
14. 🔄 **Testing** (007) - Throughout all phases - 60-80% coverage

**Rationale:** Build on stable foundation, add polish

### Phase 5: Major Refactor (Month 3)
15. 🔄 **Architecture** (004) - 2 weeks - **Last** (major refactor)

**Rationale:** Big refactor last when codebase is stable and tested

---

## Progress Overview

| Issue | Priority | Effort | Status | Completion | Category |
|-------|----------|--------|--------|------------|----------|
| 001. Security | 🔴 Critical | 1-2 days | ✅ Done | 100% | Security |
| **002. Error Handling** | 🔴 Critical | 3-4 days | 📋 Open | 0% | Architecture |
| 003. State Management | 🟠 High | 4-5 days | 📋 Open | 0% | Architecture |
| 004. Architecture | 🟡 Medium | 2 weeks | 📋 Open | 0% | Architecture |
| 005. API Networking | 🟡 Medium | 3-4 days | 📋 Open | 0% | Architecture |
| 006. Performance | 🟡 Medium | 3-4 days | 📋 Open | 0% | Performance |
| 007. Testing | 🟡 Medium | 1-2 weeks | 📋 Open | 0% | Testing |
| **010. Color Contrast** | 🔴 Critical | 2-4 hours | 📋 Open | 0% | Accessibility |
| **011. Focus Indicators** | 🔴 Critical | 2-3 hours | 📋 Open | 0% | Accessibility |
| **012. Link Differentiation** | 🔴 Critical | 1-2 hours | 📋 Open | 0% | Accessibility |
| **013. Mobile Navigation** | 🟠 High | 4-6 hours | 📋 Open | 0% | Mobile UX |
| 014. Button Hierarchy | 🟠 High | 3-4 hours | 📋 Open | 0% | Visual Design |
| 015. Touch Target Sizing | 🟠 High | 2-3 hours | 📋 Open | 0% | Mobile UX |
| 016. Enhanced Error States | 🟠 High | 6-8 hours | 📋 Open | 0% | UX |
| 017. Logging Enhancements | 🟠 High | 4-6 hours | ✅ Done | 100% | Debugging/UX |
| **TOTAL** | | **~8 weeks** | | **14.3%** | |

### Summary by Category
- **Accessibility:** 3 issues (5-9 hours) - **HIGHEST PRIORITY**
- **Architecture:** 4 issues (~4 weeks)
- **Mobile UX:** 2 issues (6-9 hours)
- **Visual Design:** 1 issue (3-4 hours)
- **UX/Forms:** 1 issue (6-8 hours)
- **Debugging/UX:** 1 issue (4-6 hours)
- **Performance:** 1 issue (3-4 days)
- **Testing:** Ongoing (1-2 weeks)

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

### Main Documentation
- **Main README:** [../../README.md](../../README.md)
- **CLAUDE.md:** [../../CLAUDE.md](../../CLAUDE.md) (development workflow guide)
- **Completed Issues:** [done/](done/)

### UI/UX Documentation
- **UI/UX Assessment Report:** [UI_UX_ASSESSMENT.md](UI_UX_ASSESSMENT.md) - Comprehensive 70k+ char assessment
- **Style Guide:** [STYLEGUIDE.md](STYLEGUIDE.md) - Complete design system documentation
- **Accessibility:** Issues 010-012 (WCAG compliance)
- **Mobile UX:** Issues 013, 015 (mobile-first improvements)

### Testing & Quality
- **Testing Strategy:** [open/007-testing-strategy.md](open/007-testing-strategy.md)
- **Code Coverage:** Target 60-80%
- **Accessibility Testing:** WCAG 2.1 Level AA compliance

---

**Last Updated:** 2025-10-02
**Next Review:** After completing Phase 1 (Accessibility Compliance)
