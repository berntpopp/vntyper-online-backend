# VNtyper Online - Style Guide

**Version:** 0.40.0
**Last Updated:** 2025-10-02
**Authors:** Senior UI/UX Analysis

---

## Table of Contents

1. [Overview](#overview)
2. [Design Philosophy](#design-philosophy)
3. [Color Palette](#color-palette)
4. [Typography](#typography)
5. [Spacing System](#spacing-system)
6. [Grid & Layout](#grid--layout)
7. [Components](#components)
8. [Animations](#animations)
9. [Accessibility](#accessibility)
10. [Responsive Design](#responsive-design)

---

## Overview

VNtyper Online is a web-based bioinformatics application for MUC1-VNTR genotyping. The design system emphasizes clarity, scientific professionalism, and accessibility while maintaining a modern, clean aesthetic suitable for academic and research contexts.

### Core Principles
- **Clarity:** Information hierarchy should be immediately apparent
- **Accessibility:** WCAG 2.1 Level AA compliance minimum
- **Consistency:** Uniform spacing, colors, and interaction patterns
- **Performance:** Lightweight, fast-loading assets
- **Responsiveness:** Seamless experience across devices

---

## Design Philosophy

### Visual Language
The interface adopts a **clean, card-based layout** with generous whitespace, emphasizing content over decoration. The color scheme uses muted, professional tones (teal, orange, brown) that convey scientific credibility while avoiding clinical coldness.

### Interaction Patterns
- **Progressive disclosure:** Optional features hidden by default ("Show Options")
- **Immediate feedback:** Hover states, focus indicators, and status updates
- **Forgiving UI:** Clear error messages, tooltips on hover/focus
- **Non-blocking operations:** Background job processing with status polling

---

## Color Palette

### Primary Colors

```css
/* Primary - Dark Teal */
--color-primary: #005f73;
--color-primary-hover: #0a9396;
--color-primary-light: #94d2bd;

/* Secondary - Orange */
--color-secondary: #ee9b00;
--color-secondary-hover: #fcbf49;
--color-secondary-dark: #c17700;

/* Tertiary - Brown/Orange */
--color-tertiary: #8F4400;
--color-tertiary-hover: #ffaa00;
--color-tertiary-dark: #8a4b08;
```

**Usage:**
- **Primary (Teal):** Submit actions, primary CTAs, active states
- **Secondary (Orange):** Extract/alternative actions, warnings
- **Tertiary (Brown):** Toggle/utility actions

### Semantic Colors

```css
/* Success States */
--color-success: #3c763d;
--color-success-bg: #dff0d8;
--color-success-border: #d6e9c6;

/* Error States */
--color-error: #a94442;
--color-error-bg: #f8dede;
--color-error-border: #ebccd1;

/* Warning States */
--color-warning: #856404;
--color-warning-bg: #fff3cd;
--color-warning-border: #ffeeba;

/* Info States */
--color-info: #31708f;
--color-info-bg: #e7f3fe;
--color-info-border: #bce8f1;
```

### Neutrals

```css
/* Background & Surface */
--color-bg-page: #f9f9f9;
--color-bg-container: #ffffff;
--color-bg-output: #f4f4f4;
--color-bg-footer: #f8f9fa;

/* Text */
--color-text-primary: #333333;
--color-text-secondary: #6c757d;
--color-text-muted: #666666;
--color-text-light: #aaaaaa;

/* Borders */
--color-border-light: #e7e7e7;
--color-border-default: #ccc;
--color-border-medium: #ddd;
--color-border-dark: #888;
```

### Interactive Elements

```css
/* Links */
--color-link: #007bff;
--color-link-hover: #0056b3;

/* Focus States */
--color-focus: #0a9396;
--color-focus-outline: rgba(10, 147, 150, 0.5);

/* Drag & Drop */
--color-drag-default: #6c757d;
--color-drag-hover: #0d6efd;
--color-drag-bg-hover: #e7f1ff;
```

### Cohort System Colors

```css
--color-cohort-border: #007BFF;
--color-cohort-bg: #E6F0FF;
--color-cohort-bg-hover: #D0E7FF;
--color-cohort-text: #0056b3;
```

### Color Contrast Notes

⚠️ **Accessibility Concerns Identified:**
- Some text/background combinations need verification against WCAG AA (4.5:1 for normal text, 3:1 for large text)
- Links within body text should have 3:1 contrast ratio with surrounding text
- Focus indicators should have 3:1 contrast with adjacent colors

---

## Typography

### Font Stack

```css
font-family: Arial, sans-serif;
```

**Rationale:** Arial provides excellent cross-platform consistency and readability for scientific content. Sans-serif enhances legibility at small sizes common in data-heavy interfaces.

### Type Scale

```css
/* Headings */
--font-size-h1: 32px;      /* Page title (implied from h2 analysis) */
--font-size-h2: 32px;      /* Main heading */
--font-size-h3: 1.2em;     /* Modal titles, subsections */

/* Body Text */
--font-size-base: 16px;    /* Default body text */
--font-size-large: 1.2em;  /* Cohort info */
--font-size-medium: 1rem;  /* Standard text, form labels */
--font-size-small: 0.95em; /* Citation text */
--font-size-xsmall: 0.85rem; /* File list items */

/* UI Elements */
--font-size-button: 1rem;
--font-size-nav: 1em;
--font-size-footer: 14px;
--font-size-footer-small: 12px;
--font-size-tooltip: 0.9rem;
```

### Font Weights

```css
--font-weight-normal: 400;
--font-weight-bold: 700;    /* Labels, strong emphasis */
```

### Line Heights

```css
--line-height-base: 1.6;    /* FAQ body text */
--line-height-tight: 1;     /* Buttons, compact UI */
```

### Text Styles

```css
/* Placeholder Text */
.placeholder-message {
  font-style: italic;
  color: #666;
  text-align: center;
}

/* Citation Text */
.citation-item p {
  font-size: 0.95em;
  line-height: 1.6;
  color: #6c757d;
}

/* Job Status Text */
.job-status {
  color: #28a745; /* Success green */
}
```

---

## Spacing System

### Base Unit
**8px base unit** (implied from 10px, 15px, 20px, 30px usage - slightly inconsistent)

### Spacing Scale

```css
/* Recommended Scale (8px base) */
--space-xs: 4px;      /* Tight spacing */
--space-sm: 8px;      /* Compact spacing */
--space-md: 16px;     /* Default spacing */
--space-lg: 24px;     /* Generous spacing */
--space-xl: 32px;     /* Section spacing */
--space-xxl: 48px;    /* Major section breaks */

/* Current Usage (needs standardization) */
--space-5: 5px;
--space-10: 10px;
--space-15: 15px;
--space-20: 20px;
--space-30: 30px;
--space-40: 40px;
```

### Component Spacing

```css
/* Container Padding */
--container-padding: 30px;          /* Desktop */
--container-padding-mobile: 20px;   /* Mobile */

/* Margins */
--margin-body: 40px;               /* Desktop */
--margin-body-mobile: 20px;        /* Mobile */
--margin-section: 20px;
--margin-navbar: 30px;

/* Component Gaps */
--gap-button-group: 10px;
--gap-footer-links: 15px;
--gap-institution-logos: 20px;
```

---

## Grid & Layout

### Container System

```css
.container {
  max-width: 900px;
  margin: auto;
  background-color: #fff;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

/* Hover Enhancement */
.container:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
```

### Layout Patterns

#### Flexbox Patterns

```css
/* Navbar Layout */
.navbar-container {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* Button Group */
.button-group {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  align-items: center;
}

/* Footer Layout */
.footer-content {
  display: flex;
  flex-direction: column;
  align-items: center;
}

@media (min-width: 600px) {
  .footer-content {
    flex-direction: row;
    justify-content: space-between;
  }
}
```

### Border Radius

```css
--radius-small: 4px;    /* Inputs, buttons, minor elements */
--radius-medium: 8px;   /* Cards, containers, modals */
--radius-large: 50%;    /* Circular elements (spinner) */
```

### Shadows

```css
/* Elevation System */
--shadow-sm: 0 2px 8px rgba(0,0,0,0.1);    /* Default container */
--shadow-md: 0 4px 12px rgba(0,0,0,0.1);   /* Hover state */
--shadow-lg: 0 5px 15px rgba(0,0,0,0.3);   /* Modal */
```

---

## Components

### Buttons

#### Primary Button (Submit)

```css
.submit-button {
  display: inline-block;
  margin: 0.4rem 0.4rem;
  padding: 0.6rem 1.2rem;
  background-color: #0a9396;
  color: #ffffff;
  border: none;
  border-radius: 0.2rem;
  cursor: pointer;
  font-size: 1rem;
  transition: background-color 0.3s;
}

.submit-button:hover {
  background-color: #94d2bd;
}

.submit-button:active {
  background-color: #005f73;
}

.submit-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}
```

#### Secondary Button (Extract)

```css
.extract-button {
  background-color: #ee9b00;
}

.extract-button:hover {
  background-color: #fcbf49;
}

.extract-button:active {
  background-color: #c17700;
}
```

#### Tertiary Button (Toggle/Options)

```css
.toggle-button {
  background-color: #8F4400;
}

.toggle-button:hover {
  background-color: #ffaa00;
}

.toggle-button:active {
  background-color: #8a4b08;
}
```

#### Download Button/Link

```css
.download-link {
  display: inline-block;
  margin: 0.4rem 0.4rem;
  padding: 0.3rem 0.6rem;
  background-color: #3498db;
  color: #fff;
  text-decoration: none;
  border-radius: 4px;
  font-size: 0.8rem;
  transition: background-color 0.3s ease;
}

.download-link:hover {
  background-color: #2980b9;
}

.download-link:active {
  background-color: #1c5d99;
}
```

### Forms

#### Input Fields

```css
.form-input, .form-select {
  width: 100%;
  padding: 10px;
  font-size: 1rem;
  margin-bottom: 15px;
  border: 1px solid #ccc;
  border-radius: 4px;
  box-sizing: border-box;
}

.form-select:focus {
  border-color: #80bdff;
  outline: none;
  box-shadow: 0 0 5px rgba(0,123,255,0.5);
}
```

#### Drag & Drop Area

```css
.drag-drop-area {
  border: 2px dashed #6c757d;
  border-radius: 0.4rem;
  padding: 1.0rem;
  text-align: center;
  color: #6c757d;
  transition: background-color 0.3s, border-color 0.3s, color 0.3s;
  cursor: pointer;
  height: 120px;
}

.drag-drop-area:hover,
.drag-drop-area:focus,
.drag-drop-area.dragover {
  border-color: #0d6efd;
  background-color: #e7f1ff;
  color: #0d6efd;
}
```

### Messages & Alerts

```css
/* Info Message */
.message-info {
  background-color: #e7f3fe;
  color: #31708f;
  border: 1px solid #bce8f1;
  padding: 10px;
  border-radius: 5px;
}

/* Success Message */
.message-success {
  background-color: #dff0d8;
  color: #3c763d;
  border: 1px solid #d6e9c6;
}

/* Warning Message */
.message-warning {
  background-color: #fff3cd;
  color: #856404;
  border: 1px solid #ffeeba;
  font-weight: bold;
  border-left: 4px solid #ffc107;
}

/* Error Message */
.message-error {
  background-color: #f8dede;
  color: #a94442;
  border: 1px solid #ebccd1;
}
```

### Modals

```css
.modal {
  display: none;
  position: fixed;
  z-index: 1001;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  overflow: auto;
}

.modal-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0,0,0,0.5);
}

.modal-content {
  position: relative;
  background-color: #ffffff;
  margin: 5% auto;
  padding: 20px;
  border: 1px solid #888;
  width: 80%;
  max-width: 800px;
  border-radius: 8px;
  box-shadow: 0 5px 15px rgba(0,0,0,0.3);
  animation: modalopen 0.4s;
}

@keyframes modalopen {
  from { opacity: 0; }
  to { opacity: 1; }
}
```

### Navigation Bar

```css
.navbar {
  max-width: 900px;
  margin: auto;
  padding: 10px 10px;
  margin-bottom: 30px;
}

.navbar-menu {
  list-style: none;
  display: flex;
  align-items: center;
  gap: 20px;
}

.navbar-link {
  text-decoration: none;
  color: #333333;
  font-size: 1em;
  transition: color 0.3s ease;
}

.navbar-link:hover,
.navbar-link:focus {
  color: #096162;
}
```

### Tooltips

```css
[data-tooltip]::after {
  content: attr(data-tooltip);
  position: absolute;
  bottom: 125%;
  left: 50%;
  transform: translateX(-50%);
  background-color: #333;
  color: #fff;
  padding: 6px 8px;
  border-radius: 4px;
  white-space: nowrap;
  font-size: 0.9rem;
  opacity: 0;
  visibility: hidden;
  transition: opacity 0.3s;
  z-index: 10;
}

[data-tooltip]:hover::after,
[data-tooltip]:focus::after {
  opacity: 1;
  visibility: visible;
}
```

### Spinner

```css
.spinner {
  border: 8px solid #f3f3f3;
  border-top: 8px solid #3498db;
  border-radius: 50%;
  width: 20px;
  height: 20px;
  animation: spin 2s linear infinite;
  margin: 10px auto;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
```

---

## Animations

### Logo Animation

```css
.logo {
  animation: logoPulse 3s ease-in-out infinite;
  transform-origin: center;
}

@keyframes logoPulse {
  0% { transform: scale(1); }
  50% { transform: scale(1.05); }
  100% { transform: scale(1); }
}
```

### App Name Animation

```css
.header h2 {
  opacity: 0;
  animation: appNameFadeInSlideIn 1.5s ease-out forwards;
  animation-delay: 0.5s;
}

@keyframes appNameFadeInSlideIn {
  0% { opacity: 0; transform: translateX(-20px); }
  100% { opacity: 1; transform: translateX(0); }
}
```

### Transition Timing

```css
--transition-fast: 0.3s;
--transition-medium: 0.4s;
--transition-slow: 1.5s;
```

---

## Accessibility

### Focus States

```css
button:focus,
input:focus,
select:focus {
  outline: 2px solid #0a9396;
  outline-offset: 2px;
}
```

### ARIA Support
- All interactive elements have `aria-label` attributes
- Modals use `role="dialog"`, `aria-modal="true"`, `aria-labelledby`, `aria-describedby`
- Dynamic content regions use `aria-live="polite"` and `aria-atomic`
- Buttons indicate expanded state with `aria-expanded`
- Form inputs connected to labels via `aria-describedby`

### Keyboard Navigation
- Tab order follows logical reading order
- All interactive elements focusable
- Tooltips visible on both hover and focus
- Modals closable via Escape key (implied best practice)

### Screen Reader Support
- Semantic HTML structure (`<nav>`, `<main>`, `<footer>`, `<section>`)
- Hidden file inputs maintain accessibility through associated labels
- Status updates announced via `aria-live` regions

---

## Responsive Design

### Breakpoints

```css
/* Mobile First Approach */
--breakpoint-mobile: 375px;   /* iPhone SE */
--breakpoint-mobile-l: 425px; /* Large phones */
--breakpoint-tablet: 768px;   /* Tablets */
--breakpoint-desktop: 1024px; /* Small desktops */
--breakpoint-desktop-l: 1920px; /* Large desktops */
```

### Media Query Usage

```css
/* Mobile (< 600px) */
@media (max-width: 600px) {
  body {
    margin: 20px;
    font-size: 16px;
  }

  .container {
    padding: 20px;
    margin: 20px;
  }

  .button-group {
    flex-direction: column;
    align-items: stretch;
  }

  .button {
    width: 100%;
  }
}

/* Tablet and above (≥ 600px) */
@media (min-width: 600px) {
  .footer-content {
    flex-direction: row;
    justify-content: space-between;
  }
}

/* Tablet (≤ 768px) */
@media (max-width: 768px) {
  .navbar-menu {
    flex-direction: column;
    align-items: flex-start;
  }
}
```

### Responsive Patterns

#### Stacking Pattern
- Buttons stack vertically on mobile
- Footer content stacks on mobile, horizontal on desktop
- Logo and navigation stack on tablet

#### Fluid Typography
- Base font size increases from 14px to 16px on mobile for readability
- Maintains proportional scaling across breakpoints

#### Touch Targets
- Buttons minimum 44x44px on mobile (currently ~40x40px, needs improvement)
- Adequate spacing between interactive elements

---

## File Organization

```
frontend/resources/css/
├── base.css              # Global styles, resets, utilities
├── navbar.css            # Navigation bar styles
├── drag-drop.css         # File upload component
├── forms.css             # Form inputs and button groups
├── buttons.css           # Button variations
├── ui-components.css     # Spinner, countdown, share container
├── output.css            # Results display area
├── modal.css             # Modal dialogs
├── faq.css               # FAQ accordion styles
├── citations.css         # Citation section
├── footer.css            # Footer styles
├── log.css               # Logging panel
└── usageStats.css        # Usage statistics panel
```

---

## Browser Support

### Tested Browsers
- Chrome 90+ ✓
- Firefox 88+ ✓
- Safari 14+ ✓
- Edge 90+ ✓

### Fallbacks
- CSS Grid with Flexbox fallback
- Modern CSS features with vendor prefixes
- SVG icons with PNG fallbacks (logos)

---

## Code Examples

### Creating a Custom Button

```html
<button class="button submit-button" data-tooltip="Submit your analysis">
  Submit Jobs
</button>
```

### Creating a Message Alert

```html
<div class="message message-warning">
  ⚠️ Your file is larger than recommended. Processing may take longer.
</div>
```

### Creating a Form Group

```html
<div class="region-select">
  <label for="region">Select reference:</label>
  <select id="region" class="form-select" aria-label="Select Reference Assembly">
    <option value="guess" selected>Guess assembly</option>
    <option value="hg38">hg38</option>
  </select>
</div>
```

---

## Maintenance Notes

### Known Issues
1. Spacing scale not fully consistent (mix of 5px, 10px, 15px, 20px increments)
2. Some color contrast ratios need verification for WCAG compliance
3. Focus indicators inconsistent across components
4. Button hierarchy could be clearer through size differentiation

### Future Enhancements
1. Implement CSS custom properties (CSS variables) for easier theming
2. Consider dark mode support
3. Expand color palette with tints and shades
4. Implement consistent spacing scale (8px grid)
5. Add loading skeleton states for better perceived performance
6. Create reusable component library

---

## Version History

- **v0.40.0** (2025-10-02): Initial style guide documentation
- **v0.38.0** (Previous): SOLID principles refactor
- **v0.17.1** (API): Backend version alignment

---

**Document Maintained By:** VNtyper Development Team
**Contact:** See [GitHub Repository](https://github.com/berntpopp/vntyper-online-backend)
