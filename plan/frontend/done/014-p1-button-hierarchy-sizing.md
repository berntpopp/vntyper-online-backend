# [P1] Improve Button Hierarchy and Sizing

**Priority:** P1 - High | **Effort:** Low-Medium (3-4 hours) | **Impact:** Medium-High

---

## Problem

All primary action buttons have similar visual weight. Button sizing doesn't clearly indicate primary vs. secondary actions, leading to decision paralysis and unclear user flow.

**Current State:**
- Submit Jobs, Extract Region, Show Options: All same size
- Visual hierarchy relies only on color
- No size differentiation

---

## Solution

### Three-Tier Button System

**Primary (Most Important):**
```css
.button-primary {
  padding: 0.75rem 1.5rem; /* Larger */
  font-size: 1.1rem;
  font-weight: 600;
  min-width: 160px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
```

**Secondary (Important):**
```css
.button-secondary {
  padding: 0.6rem 1.2rem; /* Current size */
  font-size: 1rem;
  font-weight: 500;
  min-width: 150px;
}
```

**Tertiary (Utility):**
```css
.button-tertiary {
  padding: 0.5rem 1rem; /* Smaller */
  font-size: 0.95rem;
  background: transparent;
  border: 2px solid currentColor;
}
```

---

## Application

- **Submit Jobs:** Primary (largest, filled, elevated)
- **Extract Region:** Secondary (medium, filled)
- **Show Options:** Tertiary (outlined, smaller)

---

## Files

- `frontend/resources/css/buttons.css`
- `frontend/resources/css/forms.css`

---

**Labels:** `P1-high`, `UX`, `visual-hierarchy`, `frontend`, `CSS`
