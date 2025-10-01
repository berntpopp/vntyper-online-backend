# Testing Strategy

**Priority:** 🟡 **MEDIUM**
**Effort:** 1-2 weeks (ongoing)
**Status:** Open

---

## Executive Summary

**Zero test coverage (0%).** No testing infrastructure. Target: **60-80% coverage**.

---

## Testing Stack

### Unit Tests: Vitest
```bash
npm install -D vitest @vitest/ui jsdom
```

### Integration Tests: Vitest + MSW
```bash
npm install -D msw
```

### E2E Tests: Playwright
```bash
npm install -D @playwright/test
```

---

## Test Structure

```
tests/
├── unit/
│   ├── errorHandling.test.js
│   ├── stateManager.test.js
│   ├── blobManager.test.js
│   └── validators.test.js
├── integration/
│   ├── jobSubmission.test.js
│   ├── cohortFlow.test.js
│   └── polling.test.js
└── e2e/
    ├── jobSubmission.spec.js
    ├── bamExtraction.spec.js
    └── cohortAnalysis.spec.js
```

---

## Priority Tests

### 1. Unit Tests (Week 1)
- [ ] Error handler
- [ ] State manager
- [ ] Blob manager
- [ ] Validators
- [ ] HTTP client

### 2. Integration Tests (Week 1)
- [ ] Job submission flow
- [ ] Polling logic
- [ ] Cohort creation

### 3. E2E Tests (Week 2)
- [ ] Complete job workflow
- [ ] BAM extraction
- [ ] Error scenarios

---

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm install
      - run: npm test
      - run: npm run test:e2e
```

---

## Success Criteria

- [ ] 60-80% code coverage
- [ ] All critical paths tested
- [ ] Tests run in CI/CD
- [ ] E2E tests for main workflows

---

**Created:** 2025-10-01
