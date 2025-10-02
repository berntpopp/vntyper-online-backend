# [P1] Increase Touch Target Sizes for Mobile

**Priority:** P1 - High | **Effort:** Low (2-3 hours) | **Impact:** High

---

## Problem

Several interactive elements are below the recommended 44×44px minimum for mobile touch targets (WCAG 2.5.5 Level AAA), leading to misclicks and frustration.

**Current Violations:**
- Reset file button (↺): ~20×20px ❌
- Remove file buttons (×): ~16×16px ❌
- Modal close button (×): ~24×24px ❌
- Copy button (📋): ~32×32px ⚠️

---

## Solution

```css
/* Minimum 44×44px touch targets */
.reset-file-selection-button,
.file-list .remove-file,
.modal-close,
.copy-button {
  min-width: 44px;
  min-height: 44px;
  padding: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.reset-file-selection-button {
  font-size: 1.5rem; /* Increased from 1.2rem */
}

.file-list .remove-file {
  font-size: 1.2rem; /* Increased from 1rem */
}

.modal-close {
  font-size: 2rem; /* Increased from 1.5em */
}
```

---

## Files

- `frontend/resources/css/drag-drop.css`
- `frontend/resources/css/modal.css`
- `frontend/resources/css/ui-components.css`

---

**Labels:** `P1-high`, `mobile`, `accessibility`, `touch-targets`, `frontend`, `CSS`
