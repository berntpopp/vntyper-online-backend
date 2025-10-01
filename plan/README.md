# VNTyper Planning

Simple planning structure for tracking refactoring and improvements across the VNtyper Online project.

---

## Structure

```
plan/
├── frontend/          # Frontend submodule issues
│   ├── open/          # Issues to be done
│   └── done/          # Completed issues
├── backend/           # Backend submodule issues
│   ├── open/
│   └── done/
├── orchestration/     # This repo: proxy, certbot, docker-compose
│   ├── open/
│   └── done/
└── archive/           # Old/deprecated plans
```

---

## Usage

### Adding a New Issue

1. Determine which category: `frontend/`, `backend/`, or `orchestration/`
2. Create a markdown file in the `open/` subfolder
3. Use a descriptive filename: `NNN-short-description.md`
4. Include: problem description, proposed solution, implementation steps

### Completing an Issue

1. Move the file from `open/` to `done/`
2. Add completion date and any notes about the implementation

### Example Issue Format

```markdown
# Issue Title

**Priority:** CRITICAL | HIGH | MEDIUM | LOW
**Effort:** X days
**Status:** Open | In Progress | Done

## Problem

Description of the issue

## Solution

Proposed approach

## Steps

1. Step 1
2. Step 2

## Notes

Any additional context
```

---

## Current Status

### Frontend
- Open: Check `frontend/open/`
- Done: Check `frontend/done/`

### Backend
- Open: Check `backend/open/`
- Done: Check `backend/done/`

### Orchestration
- Open: Check `orchestration/open/`
- Done: Check `orchestration/done/`

---

**Last Updated:** 2025-10-01
