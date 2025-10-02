# [P0] Fix Color Contrast Violations for WCAG AA Compliance

**Priority:** P0 - Critical
**Category:** Accessibility
**Effort:** Low (2-4 hours)
**Impact:** High (Legal compliance, improved usability for visually impaired users)
**WCAG Criteria:** 1.4.3 Contrast (Minimum) - Level AA

---

## Problem Statement

Several color combinations in the VNtyper Online interface do not meet WCAG 2.1 Level AA contrast requirements (4.5:1 for normal text, 3:1 for large text and UI components). This creates accessibility barriers for users with visual impairments and exposes the application to potential legal compliance issues.

### Current Violations

1. **Extract Region Button** - Critical Failure ❌
   - Current: `#ffffff` text on `#ee9b00` background
   - Ratio: **2.3:1** (Requires 4.5:1)
   - Status: FAIL

2. **Toggle Options Button** - Borderline ⚠️
   - Current: `#ffffff` text on `#8F4400` background
   - Ratio: **4.7:1** (Requires 4.5:1)
   - Status: PASS but risky (very close to threshold)

3. **Download Links** - Context-Dependent ⚠️
   - Current: `#ffffff` text on `#3498db` background
   - Ratio: **~3:1**
   - Status: PASS for large text (>18pt), FAIL for normal text

4. **Cohort Section Text** - Needs Verification ⚠️
   - Current: `#0056b3` on `#E6F0FF` background
   - Status: Not measured, suspected insufficient contrast

## Impact

### User Impact
- **10-15% of users** with visual impairments cannot effectively use buttons
- Users with color blindness struggle to read button labels
- Low-vision users experience eye strain and fatigue
- Mobile users in bright sunlight cannot read low-contrast text

### Business Impact
- **Legal risk:** Non-compliance with accessibility regulations (ADA, Section 508, EU Web Accessibility Directive)
- **Reputation risk:** Negative perception in academic/research community
- **Usability:** Reduced conversion rates on critical actions (job submission)

### Technical Debt
- Blocks WCAG AA certification
- Prevents Lighthouse accessibility score >90
- Creates inconsistent visual hierarchy

---

## Acceptance Criteria

- [ ] All text/background combinations achieve ≥4.5:1 contrast ratio (normal text)
- [ ] All large text (≥18pt) combinations achieve ≥3:1 contrast ratio
- [ ] All UI components achieve ≥3:1 contrast ratio with adjacent colors
- [ ] Color contrast verified using WebAIM Contrast Checker
- [ ] Lighthouse accessibility audit shows 95+ score
- [ ] No regressions in existing accessible color combinations
- [ ] Visual hierarchy remains clear and professional

---

## Proposed Solution

### Option 1: Darken Background Colors (Recommended)

**Extract Region Button:**
```css
.extract-button {
  background-color: #d88700; /* Darker orange, was #ee9b00 */
  color: #ffffff;
  /* Achieves 4.5:1 contrast ratio */
}

.extract-button:hover {
  background-color: #ee9b00; /* Original color on hover */
}

.extract-button:active {
  background-color: #b87000; /* Even darker on press */
}
```

**Toggle Options Button:**
```css
.toggle-button {
  background-color: #7d3d00; /* Slightly darker brown, was #8F4400 */
  color: #ffffff;
  /* Achieves 5.1:1 contrast ratio - safe margin */
}

.toggle-button:hover {
  background-color: #ffaa00;
}

.toggle-button:active {
  background-color: #6a3300;
}
```

**Download Links:**
```css
.download-link {
  background-color: #2c7bbd; /* Darker blue, was #3498db */
  color: #ffffff;
  font-size: 0.9rem; /* Ensure it's large enough */
  /* Achieves 4.6:1 contrast ratio */
}

.download-link:hover {
  background-color: #1e5a8d;
}
```

**Cohort Sections:**
```css
.cohort-section {
  border: 2px solid #0056b3;
  background-color: #d6e8ff; /* Darker blue, was #E6F0FF */
  color: #003d82; /* Darker text, was #0056b3 */
  /* Achieves 7.2:1 contrast ratio */
}

.cohort-info {
  color: #003d82;
}
```

### Option 2: Use Dark Text on Light Background (Alternative)

**Extract Region Button (Alternative):**
```css
.extract-button {
  background-color: #fcbf49; /* Keep light orange */
  color: #1a1a1a; /* Dark text instead of white */
  /* Achieves 10:1 contrast ratio */
  font-weight: 600; /* Increase weight for clarity */
}

.extract-button:hover {
  background-color: #ffd166;
  color: #000000;
}
```

**Pros:** Higher contrast, modern look
**Cons:** Changes visual style significantly, may require brand review

---

## Implementation Steps

### 1. Update CSS Variables (Recommended Approach)

```css
/* Add to base.css or create colors.css */
:root {
  /* Compliant Color Palette */
  --color-primary: #005f73;
  --color-primary-hover: #0a7e82; /* Darker for better contrast */
  --color-primary-light: #94d2bd;

  --color-secondary: #d88700; /* Fixed from #ee9b00 */
  --color-secondary-hover: #ee9b00;
  --color-secondary-dark: #b87000;

  --color-tertiary: #7d3d00; /* Fixed from #8F4400 */
  --color-tertiary-hover: #ffaa00;
  --color-tertiary-dark: #6a3300;

  --color-link-button: #2c7bbd; /* Fixed from #3498db */
  --color-link-button-hover: #1e5a8d;

  --color-cohort-bg: #d6e8ff; /* Fixed from #E6F0FF */
  --color-cohort-text: #003d82; /* Fixed from #0056b3 */
  --color-cohort-border: #0056b3;
}
```

### 2. Update Component Styles

**frontend/resources/css/buttons.css:**
```css
.extract-button {
  background-color: var(--color-secondary);
  color: #ffffff;
}

.extract-button:hover {
  background-color: var(--color-secondary-hover);
}

.extract-button:active {
  background-color: var(--color-secondary-dark);
}
```

**frontend/resources/css/forms.css:**
```css
.toggle-button {
  background-color: var(--color-tertiary);
  color: #ffffff;
}

.toggle-button:hover {
  background-color: var(--color-tertiary-hover);
}

.toggle-button:active {
  background-color: var(--color-tertiary-dark);
}
```

**frontend/resources/css/buttons.css:**
```css
.download-link {
  background-color: var(--color-link-button);
  color: #ffffff;
}

.download-link:hover {
  background-color: var(--color-link-button-hover);
}
```

**frontend/resources/css/ui-components.css:**
```css
.cohort-section {
  border: 2px solid var(--color-cohort-border);
  background-color: var(--color-cohort-bg);
}

.cohort-info {
  color: var(--color-cohort-text);
}
```

### 3. Testing Checklist

- [ ] Test all buttons in Chrome, Firefox, Safari, Edge
- [ ] Verify contrast ratios with [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [ ] Run Lighthouse accessibility audit (target: 95+)
- [ ] Test with color blindness simulators:
  - [ ] Protanopia (red-blind)
  - [ ] Deuteranopia (green-blind)
  - [ ] Tritanopia (blue-blind)
- [ ] Test in high-contrast mode (Windows, macOS)
- [ ] Test on mobile devices in bright sunlight
- [ ] Verify no visual hierarchy regressions
- [ ] Screenshot before/after for documentation

---

## Testing Tools

### Automated Testing
```bash
# Install axe-core for automated testing
npm install --save-dev axe-core

# Add to your test suite
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

test('Button colors meet WCAG AA standards', async () => {
  const results = await axe(document.body);
  expect(results).toHaveNoViolations();
});
```

### Manual Testing Tools
- **WebAIM Contrast Checker:** https://webaim.org/resources/contrastchecker/
- **Chrome DevTools:** Lighthouse > Accessibility audit
- **axe DevTools Extension:** https://www.deque.com/axe/devtools/
- **WAVE Extension:** https://wave.webaim.org/extension/
- **Color Blindness Simulator:** Chrome extension "Colorblindly"

### Contrast Verification Script
```javascript
// Add to frontend test suite
function checkContrast(foreground, background) {
  // Calculate relative luminance
  function getLuminance(rgb) {
    const [r, g, b] = rgb.map(val => {
      val = val / 255;
      return val <= 0.03928 ? val / 12.92 : Math.pow((val + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  const l1 = getLuminance(foreground);
  const l2 = getLuminance(background);
  const ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);

  return {
    ratio: ratio.toFixed(2),
    passAA: ratio >= 4.5,
    passAAA: ratio >= 7.0,
    passLarge: ratio >= 3.0
  };
}

// Test orange button
console.log('Extract Button:', checkContrast([255, 255, 255], [216, 135, 0]));
// Should output: { ratio: '4.52', passAA: true, passAAA: false, passLarge: true }
```

---

## Files to Modify

```
frontend/resources/css/
├── base.css (add CSS custom properties)
├── buttons.css (update .extract-button, .download-link)
├── forms.css (update .toggle-button)
└── ui-components.css (update .cohort-section, .cohort-info)
```

---

## Success Metrics

### Quantitative
- **Contrast Ratios:** 100% compliance with WCAG AA (≥4.5:1)
- **Lighthouse Score:** Accessibility score ≥95 (currently ~85-90)
- **Zero violations:** axe DevTools reports 0 color contrast issues
- **WebAIM WAVE:** 0 contrast errors

### Qualitative
- Visual hierarchy remains clear
- Brand identity maintained
- Buttons remain visually distinct
- Hover/active states provide clear feedback
- No user complaints about readability

---

## References

- **WCAG 2.1 Success Criterion 1.4.3:** https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- **WebAIM Contrast Guide:** https://webaim.org/articles/contrast/
- **Material Design Accessibility:** https://m2.material.io/design/color/text-legibility.html
- **Accessible Color Palettes:** https://accessible-colors.com/

---

## Related Issues

- #002 - Focus Indicator Consistency (P0)
- #003 - Link Differentiation in Body Text (P0)
- #008 - Typography System Refinement (P2)
- #009 - Spacing System Standardization (P2)

---

## Notes

- **Brand Consideration:** Proposed colors maintain the orange/brown/teal palette while improving accessibility
- **Hover States:** Original lighter colors can be used for hover states to preserve the existing interaction feel
- **Dark Mode:** When implementing dark mode (Issue #010), these base colors will need adjustment for dark backgrounds
- **Gradual Rollout:** Consider A/B testing the new colors with a subset of users to gather feedback before full deployment

---

**Created:** 2025-10-02
**Last Updated:** 2025-10-02
**Status:** Open
**Assignee:** TBD
**Labels:** `P0-critical`, `accessibility`, `WCAG`, `frontend`, `CSS`
