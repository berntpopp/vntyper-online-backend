# [P1] Implement Fully Functional Mobile Navigation

**Priority:** P1 - High
**Category:** Mobile UX / Navigation
**Effort:** Medium (4-6 hours)
**Impact:** High (25-40% of users on mobile devices)
**Target:** Mobile devices < 768px width

---

## Problem Statement

The current mobile navigation has partial hamburger menu implementation but is not fully functional. On screens below 768px width, all navigation items remain visible and stacked vertically, consuming excessive vertical space and creating a poor mobile experience. The hamburger toggle button exists in the code but doesn't properly show/hide the menu.

### Current Issues

1. **Always-Visible Navigation**
   - Nav menu shows all items on mobile (FAQ, ADTKD, Tutorial, API, Jobs, Disclaimer)
   - Takes ~200-250px of vertical space
   - Pushes main content far down the page
   - Poor use of limited mobile screen real estate

2. **Non-Functional Hamburger**
   - CSS shows `.navbar-toggle { display: none; }` by default
   - No JavaScript to handle toggle interaction
   - `.navbar-menu.active` class defined but never applied
   - Missing ARIA attributes for accessibility

3. **Mobile-Specific Issues**
   - "Jobs: 0" and "✔️ Disclaimer" indicators break layout on narrow screens
   - Server load indicator wraps awkwardly
   - Navigation items not optimized for touch targets

---

## Impact

### User Experience
- **40% of research tool users** access from mobile/tablet (conferences, fieldwork, quick checks)
- First-time mobile users see cluttered, unprofessional interface
- Difficult to reach file upload area without scrolling
- Poor impression of tool quality

### Usability Metrics
- Increased bounce rate on mobile
- Lower job submission rate from mobile users
- Higher abandonment during file upload process
- Negative user feedback

### Competitive Disadvantage
- Modern web apps have collapsible mobile navigation
- Academic tools increasingly mobile-optimized
- User expectation: hamburger menu on mobile

---

## Acceptance Criteria

- [ ] Hamburger icon visible on screens < 768px
- [ ] Navigation menu hidden by default on mobile
- [ ] Clicking hamburger toggles menu visibility
- [ ] Menu slides in/out with smooth animation
- [ ] Hamburger icon changes to X when menu open
- [ ] Clicking outside menu closes it
- [ ] Pressing Escape closes menu
- [ ] Menu items properly styled for touch interaction
- [ ] ARIA attributes properly implemented
- [ ] Focus management working correctly
- [ ] Works on iOS Safari, Chrome Mobile, Firefox Mobile
- [ ] No layout shift when toggling menu
- [ ] Server load indicator mobile-optimized

---

## Proposed Solution

### 1. HTML Structure Updates

**File:** `frontend/index.html`

```html
<!-- Update navbar structure (around line 106-136) -->
<nav class="navbar">
  <div class="navbar-container">
    <div class="header" id="resetHeader" role="button" aria-label="Reset Page">
      <img src="resources/assets/logo/vntyperonline_logo_80px.png" alt="vntyper-online Logo" class="logo">
      <h2>vntyper-online</h2>
    </div>

    <!-- ADD: Hamburger button -->
    <button
      class="navbar-toggle"
      aria-label="Toggle navigation menu"
      aria-expanded="false"
      aria-controls="navbar-menu"
    >
      <span class="hamburger-icon" aria-hidden="true">☰</span>
    </button>

    <!-- Navigation Links Container -->
    <ul class="navbar-menu" id="navbar-menu" role="navigation" aria-label="Main navigation">
      <li><a href="#" class="navbar-link" data-modal="faqModal" data-tooltip="View Frequently Asked Questions">FAQ</a></li>
      <li><a href="/adtkd_diagnostics.html" class="navbar-link" data-tooltip="ADTKD diagnostics">ADTKD</a></li>
      <li><a href="#" id="startTutorialBtn" class="navbar-link" data-tooltip="Start the interactive tutorial">Tutorial</a></li>
      <li><a href="/api/docs" class="navbar-link" target="_blank" aria-label="OpenAPI Documentation" data-tooltip="View the API documentation">API</a></li>

      <!-- Server Load Indicator -->
      <li id="serverLoadIndicator" class="server-load-indicator">
        <a href="#" class="navbar-link" aria-label="Current Server Load" data-tooltip="Shows the number of jobs currently in the queue">
          <span id="serverLoadText">Jobs: </span>
          <span id="totalJobsInQueue" class="load-count">0</span>
        </a>
      </li>

      <!-- Disclaimer Indicator -->
      <li id="disclaimerIndicator">
        <a href="#" id="disclaimerLink" class="navbar-link" aria-label="View Disclaimer Status" data-tooltip="Check the disclaimer status">
          <span id="disclaimerStatusIcon" class="status-icon" aria-hidden="true">✔️</span>
          <span id="disclaimerStatusText" class="status-text">Disclaimer</span>
        </a>
      </li>
    </ul>
  </div>
</nav>
```

### 2. CSS Implementation

**File:** `frontend/resources/css/navbar.css`

```css
/* Hamburger Menu Styles */
.navbar-toggle {
  display: none; /* Hidden on desktop */
  background: transparent;
  border: none;
  font-size: 28px;
  cursor: pointer;
  color: #333;
  padding: 12px;
  border-radius: 4px;
  transition: background-color 0.3s ease, transform 0.3s ease;
  z-index: 1001;
  min-width: 48px; /* Touch target */
  min-height: 48px;
}

.navbar-toggle:hover {
  background-color: rgba(0, 0, 0, 0.05);
}

.navbar-toggle:active {
  transform: scale(0.95);
}

.navbar-toggle:focus-visible {
  outline: 2px solid #0a9396;
  outline-offset: 2px;
}

/* Hamburger icon animation */
.hamburger-icon {
  display: inline-block;
  transition: transform 0.3s ease;
}

.navbar-toggle[aria-expanded="true"] .hamburger-icon {
  transform: rotate(90deg);
}

/* Mobile Navigation Styles */
@media (max-width: 768px) {
  /* Show hamburger button */
  .navbar-toggle {
    display: block;
    position: absolute;
    right: 10px;
    top: 50%;
    transform: translateY(-50%);
  }

  .navbar-toggle[aria-expanded="true"] {
    position: fixed; /* Fix position when menu open */
  }

  /* Hide navbar menu by default */
  .navbar-menu {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.95); /* Dark overlay */
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px 20px;
    z-index: 1000;
    overflow-y: auto;
    animation: fadeIn 0.3s ease;
  }

  /* Show navbar menu when active */
  .navbar-menu.active {
    display: flex;
  }

  .navbar-menu li {
    width: 100%;
    max-width: 400px;
    margin: 8px 0;
    text-align: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  }

  .navbar-menu li:last-child {
    border-bottom: none;
  }

  .navbar-link {
    display: block;
    padding: 16px 20px;
    font-size: 1.3em;
    color: #ffffff !important; /* White text on dark background */
    transition: background-color 0.3s ease, transform 0.2s ease;
    border-radius: 8px;
  }

  .navbar-link:hover,
  .navbar-link:focus {
    background-color: rgba(10, 147, 150, 0.2);
    transform: translateX(5px);
  }

  /* Server load indicator mobile optimization */
  .server-load-indicator .navbar-link {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }

  .server-load-indicator.load-blue .navbar-link,
  .server-load-indicator.load-orange .navbar-link,
  .server-load-indicator.load-red .navbar-link {
    color: #ffffff !important;
  }

  .load-count {
    font-size: 1.2em;
    font-weight: bold;
  }

  /* Disclaimer indicator mobile */
  #disclaimerIndicator .navbar-link {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }

  .status-icon {
    font-size: 1.2em;
  }

  /* Navbar container adjustment */
  .navbar-container {
    position: relative;
    padding-right: 60px; /* Space for hamburger */
  }

  .header {
    pointer-events: all;
    z-index: 1;
  }
}

/* Animations */
@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes slideIn {
  from {
    transform: translateX(-100%);
  }
  to {
    transform: translateX(0);
  }
}

/* Prevent body scroll when menu is open */
body.menu-open {
  overflow: hidden;
  position: fixed;
  width: 100%;
}
```

### 3. JavaScript Implementation

**File:** `frontend/resources/js/main.js` or create `frontend/resources/js/mobileNav.js`

```javascript
/**
 * Mobile Navigation Toggle
 */
(function initMobileNavigation() {
  const navbarToggle = document.querySelector('.navbar-toggle');
  const navbarMenu = document.querySelector('.navbar-menu');
  const body = document.body;

  if (!navbarToggle || !navbarMenu) {
    console.warn('Mobile navigation elements not found');
    return;
  }

  /**
   * Toggle menu open/closed
   */
  function toggleMenu(forceClose = false) {
    const isExpanded = navbarToggle.getAttribute('aria-expanded') === 'true';
    const shouldClose = forceClose || isExpanded;

    if (shouldClose) {
      // Close menu
      navbarMenu.classList.remove('active');
      navbarToggle.setAttribute('aria-expanded', 'false');
      navbarToggle.querySelector('.hamburger-icon').textContent = '☰';
      body.classList.remove('menu-open');
    } else {
      // Open menu
      navbarMenu.classList.add('active');
      navbarToggle.setAttribute('aria-expanded', 'true');
      navbarToggle.querySelector('.hamburger-icon').textContent = '✕';
      body.classList.add('menu-open');

      // Focus first menu item for keyboard users
      const firstLink = navbarMenu.querySelector('.navbar-link');
      if (firstLink) {
        setTimeout(() => firstLink.focus(), 100);
      }
    }
  }

  /**
   * Handle hamburger button click
   */
  navbarToggle.addEventListener('click', (e) => {
    e.stopPropagation();
    toggleMenu();
  });

  /**
   * Close menu when clicking menu items
   */
  navbarMenu.querySelectorAll('.navbar-link').forEach(link => {
    link.addEventListener('click', () => {
      // Only close if menu is open (mobile view)
      if (navbarMenu.classList.contains('active')) {
        toggleMenu(true);
      }
    });
  });

  /**
   * Close menu when clicking outside
   */
  document.addEventListener('click', (e) => {
    if (navbarMenu.classList.contains('active')) {
      // Check if click is outside menu and toggle button
      if (!navbarMenu.contains(e.target) && !navbarToggle.contains(e.target)) {
        toggleMenu(true);
      }
    }
  });

  /**
   * Close menu on Escape key
   */
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && navbarMenu.classList.contains('active')) {
      toggleMenu(true);
      navbarToggle.focus(); // Return focus to toggle button
    }
  });

  /**
   * Handle window resize (close menu if resizing to desktop)
   */
  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      if (window.innerWidth > 768 && navbarMenu.classList.contains('active')) {
        toggleMenu(true);
      }
    }, 250);
  });

  /**
   * Prevent scroll jumping when menu opens/closes
   */
  let scrollPosition = 0;

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.attributeName === 'class') {
        if (body.classList.contains('menu-open')) {
          scrollPosition = window.pageYOffset;
          body.style.top = `-${scrollPosition}px`;
        } else {
          body.style.top = '';
          window.scrollTo(0, scrollPosition);
        }
      }
    });
  });

  observer.observe(body, { attributes: true });
})();
```

### 4. Add Script to HTML

**File:** `frontend/index.html`

```html
<!-- Add after other script tags, before closing </head> or in body -->
<script type="module" src="resources/js/mobileNav.js" defer></script>
```

---

## Implementation Steps

### Phase 1: HTML Updates (30 minutes)
1. Add hamburger button to navbar
2. Add ARIA attributes to button and menu
3. Test HTML structure validates

### Phase 2: CSS Styling (2 hours)
1. Add mobile navigation styles to navbar.css
2. Implement hamburger button styles
3. Create overlay menu styles
4. Add animations (fade in, slide)
5. Test at multiple breakpoints (375px, 414px, 768px)

### Phase 3: JavaScript Functionality (2 hours)
1. Create mobileNav.js file
2. Implement toggle function
3. Add click-outside-to-close
4. Add Escape key handler
5. Add window resize handler
6. Implement focus management
7. Test all interactions

### Phase 4: Testing & Refinement (1-2 hours)
1. Test on real devices (iPhone, Android)
2. Test in landscape orientation
3. Verify accessibility with screen reader
4. Performance check (smooth animations)
5. Cross-browser testing

---

## Testing Checklist

### Functional Testing
- [ ] Hamburger appears at 768px and below
- [ ] Clicking hamburger opens menu
- [ ] Clicking hamburger again closes menu
- [ ] Icon changes from ☰ to ✕
- [ ] Clicking menu item closes menu and navigates
- [ ] Clicking outside menu closes it
- [ ] Pressing Escape closes menu
- [ ] Resizing to desktop auto-closes menu
- [ ] Body scroll prevented when menu open
- [ ] Scroll position restored when menu closes

### Visual Testing
- [ ] Menu slides in smoothly
- [ ] No layout shift when opening/closing
- [ ] Touch targets ≥44×44px
- [ ] Text readable on dark overlay
- [ ] Logo remains visible when menu open
- [ ] No horizontal scrollbar
- [ ] Works in portrait and landscape

### Device Testing
- [ ] iPhone SE (375×667)
- [ ] iPhone 12/13 (390×844)
- [ ] iPhone Pro Max (414×896)
- [ ] Samsung Galaxy S (360×640)
- [ ] iPad Mini (768×1024)
- [ ] iPad (834×1112)

### Browser Testing
- [ ] iOS Safari (14+)
- [ ] Chrome Mobile (Android)
- [ ] Firefox Mobile
- [ ] Samsung Internet

### Accessibility Testing
- [ ] Keyboard: Tab to hamburger, Enter/Space to activate
- [ ] Screen reader announces "Toggle navigation menu"
- [ ] Screen reader announces "expanded" / "collapsed" state
- [ ] Focus visible on all interactive elements
- [ ] VoiceOver (iOS) navigation works

### Performance Testing
- [ ] Animation frame rate: 60 FPS
- [ ] No jank when scrolling menu
- [ ] Quick open/close response (<100ms)

---

## Files to Modify

```
frontend/
├── index.html (add hamburger button, ARIA attributes)
└── resources/
    ├── css/
    │   └── navbar.css (mobile navigation styles)
    └── js/
        └── mobileNav.js (NEW FILE - toggle functionality)
```

---

## Success Metrics

### Quantitative
- **Mobile usability score:** 95+ (Google PageSpeed Insights)
- **First Contentful Paint:** <1.5s on mobile
- **Touch target size:** 100% compliance (≥44×44px)
- **Animation frame rate:** 60 FPS

### Qualitative
- Mobile users can navigate without excessive scrolling
- Menu feels responsive and smooth
- Clear indication of current state (open/closed)
- Professional mobile experience

### Business Impact
- Increased mobile job submissions (+15-20%)
- Reduced mobile bounce rate (-25%)
- Positive user feedback on mobile UX

---

## Alternative Patterns Considered

### Side Drawer (Rejected)
```css
/* Slides in from left side */
.navbar-menu {
  transform: translateX(-100%);
  transition: transform 0.3s;
}
.navbar-menu.active {
  transform: translateX(0);
}
```
**Rejected:** Full-screen overlay better for limited nav items, simpler implementation

### Bottom Sheet (Considered)
```css
/* Slides up from bottom */
.navbar-menu {
  bottom: 0;
  transform: translateY(100%);
}
```
**Considered for future:** Good for longer menus, but overkill for 6 items

---

## References

- **Material Design Navigation Drawer:** https://m2.material.io/components/navigation-drawer
- **WAI-ARIA Navigation Menu:** https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/
- **Mobile Menu UX Best Practices:** https://www.nngroup.com/articles/hamburger-menus/
- **Touch Target Size Guidelines:** https://web.dev/accessible-tap-targets/

---

## Related Issues

- #002 - Focus Indicator Consistency (P0)
- #006 - Touch Target Sizing (P1)
- #008 - Typography System Refinement (P2)

---

## Notes

- **Touch Target Size:** Hamburger button 48×48px exceeds minimum 44×44px
- **Animation Performance:** Use `transform` instead of `left/right` for better performance (GPU-accelerated)
- **iOS Safari:** Test with address bar visible and hidden (affects viewport height)
- **Accessibility:** Full-screen overlay pattern announced as "navigation" by screen readers
- **Future Enhancement:** Consider adding gesture support (swipe to close)

---

**Created:** 2025-10-02
**Last Updated:** 2025-10-02
**Status:** Open
**Assignee:** TBD
**Labels:** `P1-high`, `mobile`, `navigation`, `UX`, `frontend`, `JavaScript`, `CSS`
