# [P0] Implement Consistent Focus Indicators

**Status:** ✅ COMPLETED
**Completion Date:** 2025-10-02
**Implementation Time:** 2.5 hours
**Branch:** main
**Version:** 0.43.0

**Priority:** P0 - Critical
**Category:** Accessibility / Keyboard Navigation
**Effort:** Low (2-3 hours)
**Impact:** High (Enables keyboard-only users, WCAG compliance)
**WCAG Criteria:** 2.4.7 Focus Visible - Level AA, 2.4.11 Focus Not Obscured (Minimum) - Level AA

---

## ✅ Implementation Summary

All keyboard navigation and focus indicator issues have been resolved:

**CSS Implementation:**
- Universal :focus-visible system (3px outline) for keyboard navigation
- :focus fallback (2px outline) for older browsers
- :focus:not(:focus-visible) removes outline on mouse clicks
- High-contrast mode support (@media prefers-contrast: high)
- Windows High Contrast Mode support (@media forced-colors: active)
- Specific focus styles for links, buttons, form inputs, drag-drop area
- Tooltip-enabled elements maintain focus visibility

**HTML Implementation:**
- Skip-to-main-content link added (accessible via Tab from page load)
- Main content wrapped in <main id="main-content" tabindex="-1">
- Proper semantic structure for keyboard navigation

**JavaScript Implementation:**
- Enhanced modal focus trap with ARIA best practices
- Focus returns to trigger element when modal closes
- Escape key support for FAQ modal (disabled for disclaimer)
- Custom modal:close event for consistent behavior
- Store previousFocus element for proper focus management

**Files Modified:**
- `index.html` - Skip link & main content wrapper
- `resources/css/base.css` - Universal focus system & skip link styles
- `resources/css/navbar.css` - Navbar link focus indicators
- `resources/css/forms.css` - Form select focus (removed outline: none)
- `resources/css/modal.css` - Modal close button focus
- `resources/css/drag-drop.css` - Drag-drop area focus
- `resources/js/modal.js` - Enhanced focus trap with ARIA patterns

**Testing Results:**
- All interactive elements have visible focus indicators ✅
- Focus indicators maintain ≥3:1 contrast ratio ✅
- Keyboard navigation tested - Tab, Shift+Tab, Escape ✅
- Modal focus trap working correctly ✅
- No regressions in existing functionality ✅

---

## Problem Statement

While the VNtyper Online interface has basic focus indicators implemented, they are inconsistent across components and may not be visible in all contexts. Some interactive elements lack clear focus visibility, creating barriers for keyboard-only users and users who rely on visual focus indicators for navigation.

### Current State

```css
/* Existing focus styles in base.css */
button:focus,
input:focus,
select:focus {
  outline: 2px solid #0a9396;
  outline-offset: 2px;
}
```

### Issues Identified

1. **Inconsistent Application**
   - Focus styles only apply to specific elements (`button`, `input`, `select`)
   - Custom interactive elements (e.g., `[role="button"]`, `.navbar-link`) lack focus indicators
   - Tooltip-enabled elements have focus disabled: `[data-tooltip]:focus { outline: none; }`

2. **Insufficient Contrast**
   - Teal outline (#0a9396) may not have 3:1 contrast ratio against all backgrounds
   - No high-contrast mode support

3. **Missing Skip Link**
   - No "Skip to main content" link for keyboard navigation
   - Users must tab through entire navigation before reaching main content

4. **Modal Focus Management**
   - Modal focus trap not verified
   - Close button focus behavior unclear
   - Return focus to trigger element not confirmed

## Impact

### User Impact
- **2-5% of users** navigate exclusively with keyboard (disabilities, power users, assistive technology)
- Screen reader users cannot effectively navigate without clear focus indicators
- Motor-impaired users who use keyboard alternatives struggle to track position
- Creates frustration and abandonment for keyboard-dependent users

### Legal/Compliance Impact
- **WCAG 2.1 Level AA violation** (Success Criterion 2.4.7)
- Blocks accessibility certification
- Potential ADA/Section 508 compliance issues
- Cannot meet VPAT (Voluntary Product Accessibility Template) requirements

---

## Acceptance Criteria

- [ ] All interactive elements have visible focus indicators
- [ ] Focus indicators maintain ≥3:1 contrast ratio with background
- [ ] Focus indicators ≥2px thick and clearly visible
- [ ] `:focus-visible` used to differentiate mouse vs keyboard focus
- [ ] "Skip to main content" link implemented and functional
- [ ] Modal focus trap working correctly
- [ ] Focus returns to trigger element when modal closes
- [ ] High-contrast mode supported
- [ ] No regressions in existing focus behavior
- [ ] Lighthouse accessibility audit shows 100 on keyboard navigation

---

## Proposed Solution

### 1. Universal Focus Indicator System

```css
/* frontend/resources/css/base.css */

/* Remove problematic focus removal */
[data-tooltip]:focus {
  /* DELETE: outline: none; */
  outline: 2px solid #0a9396;
  outline-offset: 2px;
}

/* Universal focus-visible for modern browsers */
:focus-visible {
  outline: 3px solid #0a9396;
  outline-offset: 3px;
  border-radius: 2px;
}

/* Fallback for older browsers */
:focus {
  outline: 2px solid #0a9396;
  outline-offset: 2px;
}

/* Remove default outline when :focus-visible is supported */
:focus:not(:focus-visible) {
  outline: none;
}

/* High-contrast mode support */
@media (prefers-contrast: high) {
  :focus-visible {
    outline: 4px solid currentColor;
    outline-offset: 4px;
  }
}

/* Forced colors mode (Windows High Contrast) */
@media (forced-colors: active) {
  :focus {
    outline: 2px solid CanvasText;
  }
}

/* Links specific focus treatment */
a:focus-visible {
  outline: 2px solid #0a9396;
  outline-offset: 2px;
  text-decoration: underline;
  text-decoration-thickness: 2px;
}

/* Button focus with subtle background */
button:focus-visible,
.button:focus-visible {
  outline: 3px solid #0a9396;
  outline-offset: 2px;
  box-shadow: 0 0 0 5px rgba(10, 147, 150, 0.1);
}

/* Form input focus */
input:focus-visible,
select:focus-visible,
textarea:focus-visible {
  outline: 2px solid #0a9396;
  border-color: #0a9396;
  box-shadow: 0 0 0 3px rgba(10, 147, 150, 0.1);
}

/* Drag-drop area focus */
.drag-drop-area:focus-visible {
  outline: 3px solid #0a9396;
  outline-offset: 2px;
  border-color: #0a9396;
}
```

### 2. Skip to Main Content Link

**Add to HTML (index.html, line 103, immediately after `<body>`):**
```html
<body>
  <a href="#main-content" class="skip-to-main">Skip to main content</a>

  <div class="container" id="home">
    <!-- Add ID to main content area -->
    <div id="main-content" tabindex="-1">
      <!-- Existing drag-drop and form content -->
    </div>
    <!-- Rest of existing content -->
  </div>
</body>
```

**Add to CSS (base.css):**
```css
/* Skip to main content link */
.skip-to-main {
  position: absolute;
  left: -9999px;
  top: 0;
  z-index: 9999;
  padding: 1rem 1.5rem;
  background-color: #0a9396;
  color: #ffffff;
  text-decoration: none;
  font-weight: 600;
  border-radius: 0 0 4px 0;
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  transition: left 0.3s ease;
}

.skip-to-main:focus {
  left: 0;
  outline: 3px solid #005f73;
  outline-offset: 2px;
}

/* Ensure target has smooth scroll and visible focus */
#main-content:focus {
  outline: 2px dashed #0a9396;
  outline-offset: 4px;
}
```

### 3. Modal Focus Management

**Add to JavaScript (modal.js or main.js):**
```javascript
// Focus trap for modals
class ModalFocusTrap {
  constructor(modalElement) {
    this.modal = modalElement;
    this.focusableElements = null;
    this.firstFocusable = null;
    this.lastFocusable = null;
    this.previousFocus = null;
  }

  activate() {
    // Store element that opened modal
    this.previousFocus = document.activeElement;

    // Get all focusable elements within modal
    this.focusableElements = this.modal.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );

    if (this.focusableElements.length === 0) return;

    this.firstFocusable = this.focusableElements[0];
    this.lastFocusable = this.focusableElements[this.focusableElements.length - 1];

    // Focus first element
    this.firstFocusable.focus();

    // Add event listener for tab trapping
    this.modal.addEventListener('keydown', this.handleKeyDown.bind(this));
  }

  handleKeyDown(e) {
    if (e.key !== 'Tab') return;

    if (e.shiftKey) {
      // Shift + Tab
      if (document.activeElement === this.firstFocusable) {
        e.preventDefault();
        this.lastFocusable.focus();
      }
    } else {
      // Tab
      if (document.activeElement === this.lastFocusable) {
        e.preventDefault();
        this.firstFocusable.focus();
      }
    }
  }

  deactivate() {
    this.modal.removeEventListener('keydown', this.handleKeyDown);

    // Return focus to element that opened modal
    if (this.previousFocus && this.previousFocus.focus) {
      this.previousFocus.focus();
    }
  }
}

// Usage in modal.js
document.querySelectorAll('[data-modal]').forEach(trigger => {
  trigger.addEventListener('click', (e) => {
    e.preventDefault();
    const modalId = trigger.getAttribute('data-modal');
    const modal = document.getElementById(modalId);

    if (modal) {
      modal.style.display = 'block';
      modal.setAttribute('aria-hidden', 'false');

      // Initialize focus trap
      const focusTrap = new ModalFocusTrap(modal);
      focusTrap.activate();

      // Store reference for closing
      modal._focusTrap = focusTrap;
    }
  });
});

// Update modal close handlers
document.querySelectorAll('.modal-close, .modal-overlay').forEach(closeBtn => {
  closeBtn.addEventListener('click', (e) => {
    const modal = e.target.closest('.modal');
    if (modal) {
      modal.style.display = 'none';
      modal.setAttribute('aria-hidden', 'true');

      // Deactivate focus trap
      if (modal._focusTrap) {
        modal._focusTrap.deactivate();
        modal._focusTrap = null;
      }
    }
  });
});

// Escape key to close modal
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    const visibleModal = document.querySelector('.modal[style*="display: block"]');
    if (visibleModal) {
      visibleModal.style.display = 'none';
      visibleModal.setAttribute('aria-hidden', 'true');

      if (visibleModal._focusTrap) {
        visibleModal._focusTrap.deactivate();
        visibleModal._focusTrap = null;
      }
    }
  }
});
```

### 4. Navbar Link Focus

**Update navbar.css:**
```css
.navbar-link:focus-visible {
  outline: 2px solid #0a9396;
  outline-offset: 4px;
  text-decoration: underline;
  color: #096162;
}

/* Server load indicator focus */
.server-load-indicator a:focus-visible {
  outline: 2px solid #0a9396;
  outline-offset: 2px;
  border-radius: 4px;
}
```

---

## Implementation Steps

### Phase 1: CSS Updates (1 hour)
1. Update `base.css` with universal focus system
2. Add skip link styles to `base.css`
3. Update `navbar.css` for link focus
4. Update `buttons.css` for button focus enhancements
5. Update `forms.css` for input focus

### Phase 2: HTML Updates (30 minutes)
1. Add skip link after `<body>` tag
2. Add `id="main-content"` to content wrapper
3. Add `tabindex="-1"` to main content (allows programmatic focus)

### Phase 3: JavaScript Focus Management (1 hour)
1. Create `ModalFocusTrap` class
2. Update modal open/close handlers
3. Add Escape key listener
4. Test focus return on modal close

### Phase 4: Testing (30 minutes)
1. Keyboard-only navigation test
2. Screen reader test (NVDA/VoiceOver)
3. High-contrast mode test
4. Focus indicator visibility verification

---

## Testing Checklist

### Manual Keyboard Testing
- [ ] Press Tab from page load → Skip link appears and is focusable
- [ ] Activate skip link → Focus moves to main content
- [ ] Tab through all interactive elements → All have visible focus
- [ ] Tab through navigation → All links show focus indicator
- [ ] Tab through buttons → All buttons show focus indicator
- [ ] Tab through form inputs → All inputs show focus indicator
- [ ] Open modal → Focus trapped within modal
- [ ] Tab to end of modal → Focus loops to beginning
- [ ] Shift+Tab from start → Focus loops to end
- [ ] Press Escape in modal → Modal closes, focus returns to trigger
- [ ] Click modal close button → Focus returns to trigger

### Visual Verification
- [ ] Focus indicators visible on white background
- [ ] Focus indicators visible on light gray background (#f4f4f4)
- [ ] Focus indicators visible on colored buttons
- [ ] Focus indicator has ≥3:1 contrast ratio (measure with contrast checker)
- [ ] Focus indicator ≥2px thick

### Screen Reader Testing
- [ ] NVDA (Windows): All interactive elements announced correctly
- [ ] VoiceOver (macOS): Skip link announced and functional
- [ ] VoiceOver (iOS): Focus indicators announced
- [ ] Focus changes announced by screen reader

### Browser Testing
- [ ] Chrome (latest) - :focus-visible support
- [ ] Firefox (latest) - :focus-visible support
- [ ] Safari (latest) - :focus-visible support
- [ ] Edge (latest) - :focus-visible support

### Automated Testing
```bash
# Run axe accessibility audit
npm run test:a11y

# Expected: 0 focus-related violations
```

---

## Files to Modify

```
frontend/
├── index.html (add skip link, main content ID)
├── resources/
│   ├── css/
│   │   ├── base.css (universal focus system, skip link)
│   │   ├── navbar.css (navbar link focus)
│   │   ├── buttons.css (button focus enhancements)
│   │   └── forms.css (input focus)
│   └── js/
│       ├── modal.js (focus trap implementation) OR
│       └── main.js (add focus management if no modal.js exists)
```

---

## Success Metrics

### Quantitative
- **Lighthouse Keyboard Score:** 100 (currently ~85-90)
- **axe DevTools:** 0 focus-related violations
- **WAVE Evaluation:** 0 keyboard access errors
- **Tab stops:** All interactive elements reachable via keyboard

### Qualitative
- Keyboard-only user can complete full job submission workflow
- Focus indicators clearly visible in all contexts
- Screen reader announces focus changes correctly
- No confusion about current focus location

---

## Alternative Considerations

### Custom Focus Ring with Two Colors (Advanced)
For enhanced visibility on any background:

```css
*:focus-visible {
  /* Inner light ring */
  outline: 2px solid #F9F9F9;
  outline-offset: 0;
  /* Outer dark ring */
  box-shadow: 0 0 0 4px #193146;
}
```

**Source:** WCAG Technique C40 - Two-color focus indicator ensures visibility against both light and dark backgrounds.

**Recommendation:** Implement if single-color approach fails contrast checks in some contexts.

---

## References

- **WCAG 2.4.7 Focus Visible:** https://www.w3.org/WAI/WCAG21/Understanding/focus-visible.html
- **WCAG 2.4.11 Focus Not Obscured:** https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum
- **MDN :focus-visible:** https://developer.mozilla.org/en-US/docs/Web/CSS/:focus-visible
- **Focus Visible Polyfill:** https://github.com/WICG/focus-visible
- **WebAIM Keyboard Testing:** https://webaim.org/articles/keyboard/
- **ARIA Modal Dialog:** https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/

---

## Related Issues

- #001 - Color Contrast Compliance (P0)
- #003 - Link Differentiation in Body Text (P0)
- #004 - Mobile Navigation Enhancement (P1)
- #014 - Keyboard Shortcuts for Power Users (P3)

---

## Notes

- **Browser Support:** `:focus-visible` is supported in all modern browsers (Chrome 86+, Firefox 85+, Safari 15.4+, Edge 86+)
- **Polyfill Available:** For older browser support, use https://github.com/WICG/focus-visible
- **Testing Priority:** Test with actual screen reader users if possible (academic institution likely has accessibility testing resources)
- **Skip Link Pattern:** Common in academic/research websites, users expect this feature

---

**Created:** 2025-10-02
**Last Updated:** 2025-10-02
**Status:** Open
**Assignee:** TBD
**Labels:** `P0-critical`, `accessibility`, `keyboard-navigation`, `WCAG`, `frontend`
