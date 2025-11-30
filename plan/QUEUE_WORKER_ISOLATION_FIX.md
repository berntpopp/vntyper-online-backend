# Queue Worker Isolation Fix

**Date**: 2025-11-17
**Status**: 📋 Ready for Implementation
**Priority**: 🟡 Medium
**Complexity**: 🟢 Low (2-line change)

---

## Problem Statement

Current architecture has a **race condition** where multiple workers can consume from the same queue, preventing guaranteed fast processing for normal mode jobs.

### Current Worker Configuration

```yaml
# Worker 1: Dedicated fast worker
backend_worker_vntyper:
  command: [..., "-Q", "vntyper_queue"]  # ✅ Only vntyper_queue

# Worker 2: General worker
backend_worker:
  command: [...]  # ⚠️ NO -Q flag = consumes ALL queues
  # This worker can consume:
  # - vntyper_queue (race with Worker 1)
  # - vntyper_long_queue (no dedicated worker!)
  # - celery (general tasks)
```

### Impact

- Normal jobs can be processed by either worker (non-deterministic)
- Slow adVNTR jobs processed by general worker (not isolated)
- No guaranteed fast lane for normal mode users

---

## Solution (KISS)

**Add dedicated slow worker + restrict general worker = queue isolation**

### Architecture After Fix

```
┌─────────────────────────────────────────────────────┐
│  Task Routes (Already Correct in celery_app.py)    │
│  ┌─────────────────────────────────────────────┐   │
│  │ run_vntyper_job → vntyper_queue (default)   │   │
│  │ adVNTR mode → vntyper_long_queue (override) │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Worker 1   │ │   Worker 2   │ │   Worker 3   │
│     FAST     │ │     SLOW     │ │   GENERAL    │
├──────────────┤ ├──────────────┤ ├──────────────┤
│ vntyper      │ │ vntyper_long │ │    celery    │
│   _queue     │ │   _queue     │ │              │
│              │ │              │ │              │
│ ✅ Normal    │ │ ✅ adVNTR    │ │ ✅ Email     │
│   jobs       │ │   jobs       │ │ ✅ Cleanup   │
│   ONLY       │ │   ONLY       │ │ ✅ Cohort    │
│              │ │              │ │   analysis   │
└──────────────┘ └──────────────┘ └──────────────┘
 Concurrency:1    Concurrency:1    Default (4)
```

---

## Implementation

### File: `docker-compose.yml`

**Change #1: Add dedicated slow worker** (after line 56)

```yaml
# ═══════════════════════════════════════════════════════════
# ADDED: Dedicated worker for long-running adVNTR jobs
# ═══════════════════════════════════════════════════════════
backend_worker_vntyper_long:
  build:
    context: ./backend/docker
    dockerfile: Dockerfile
  image: vntyper:latest
  container_name: vntyper_online_worker_vntyper_long
  command: ["celery", "-A", "app.celery_app", "worker",
            "--loglevel=info",
            "--concurrency=1",
            "-Q", "vntyper_long_queue"]
  env_file:
    - ${ENV_FILE:-.env.local}
  volumes:
    - ${INPUT_VOLUME}:/opt/vntyper/input
    - ${OUTPUT_VOLUME}:/opt/vntyper/output
  depends_on:
    - redis
  networks:
    - vntyper_network
  restart: unless-stopped
```

**Change #2: Restrict general worker** (line 64)

```yaml
# ═══════════════════════════════════════════════════════════
# MODIFIED: Restrict to default queue only (prevent race)
# ═══════════════════════════════════════════════════════════
backend_worker:
  build:
    context: ./backend/docker
    dockerfile: Dockerfile
  image: vntyper:latest
  container_name: vntyper_online_worker
  command: ["celery", "-A", "app.celery_app", "worker",
            "--loglevel=info",
            "-Q", "celery"]  # CHANGED: Added -Q celery
  env_file:
    - ${ENV_FILE:-.env.local}
  volumes:
    - ${INPUT_VOLUME}:/opt/vntyper/input
    - ${OUTPUT_VOLUME}:/opt/vntyper/output
  depends_on:
    - redis
  networks:
    - vntyper_network
  restart: unless-stopped
```

**That's it. No other changes needed.**

---

## Why This is Sufficient

### ✅ Routing Already Works

Current `celery_app.py:42-44`:
```python
celery_app.conf.task_routes = {
    "app.tasks.run_vntyper_job": {"queue": "vntyper_queue"},
}
```

**Behavior:**
- Normal mode: `task.delay()` → uses `task_routes` → vntyper_queue ✅
- adVNTR mode: `task.apply_async(queue="vntyper_long_queue")` → overrides to vntyper_long_queue ✅

**Source**: [Celery docs](https://docs.celeryq.dev/en/stable/userguide/routing.html)
> "Can be overridden at task execution time using apply_async or send_task"

### ✅ No Priority Config Needed

**Separate workers = natural priority**:
- Fast worker always available for normal jobs
- Slow worker can't block fast jobs
- No need for Redis priority queues (simpler, more reliable)

### ✅ No Queue Tracking Changes Needed

Use Celery's built-in inspection:
```python
from celery import current_app

# Get queue info
inspect = current_app.control.inspect()
active = inspect.active()
reserved = inspect.reserved()
```

**DRY**: Don't duplicate what Celery provides!

---

## Testing

### Unit Tests

**Not needed** - no code changes, only deployment config.

### Integration Test

**File**: `backend/tests/integration/test_worker_isolation.py` (NEW)

```python
"""Test worker queue isolation."""

import pytest


def test_workers_consume_correct_queues():
    """Verify each worker only consumes from assigned queue."""
    from celery import current_app

    inspect = current_app.control.inspect()
    active_queues = inspect.active_queues()

    # Verify worker assignments
    for worker_name, queues in active_queues.items():
        queue_names = [q['name'] for q in queues]

        if 'worker_vntyper@' in worker_name:
            assert queue_names == ['vntyper_queue']
        elif 'worker_vntyper_long@' in worker_name:
            assert queue_names == ['vntyper_long_queue']
        elif 'worker@' in worker_name:
            assert queue_names == ['celery']
```

### Manual Verification

```bash
# 1. Start services
./dev.sh up

# 2. Check worker queues
docker logs vntyper_online_worker_vntyper 2>&1 | grep "consuming from"
# Expected: [queues] vntyper_queue

docker logs vntyper_online_worker_vntyper_long 2>&1 | grep "consuming from"
# Expected: [queues] vntyper_long_queue

docker logs vntyper_online_worker 2>&1 | grep "consuming from"
# Expected: [queues] celery

# 3. Submit test jobs
curl -X POST http://localhost:8000/api/run-job/ \
  -F "bam_file=@test.bam" \
  -F "advntr_mode=false"

# Watch fast worker logs
docker logs -f vntyper_online_worker_vntyper
# Should see task execution

curl -X POST http://localhost:8000/api/run-job/ \
  -F "bam_file=@test.bam" \
  -F "advntr_mode=true"

# Watch slow worker logs
docker logs -f vntyper_online_worker_vntyper_long
# Should see task execution

# 4. Verify no race conditions
# Submit 10 normal jobs rapidly
for i in {1..10}; do
  curl -X POST http://localhost:8000/api/run-job/ \
    -F "bam_file=@test$i.bam" \
    -F "advntr_mode=false"
done

# All should be processed by vntyper_online_worker_vntyper ONLY
docker-compose logs backend_worker | grep "run_vntyper_job"
# Should be empty (general worker not processing VNtyper jobs)
```

---

## Regression Prevention

### Checklist

- [ ] Existing normal jobs still work
- [ ] Existing adVNTR jobs still work
- [ ] Cohort analysis still works (uses default queue)
- [ ] Email notifications still work (uses default queue)
- [ ] Periodic cleanup still works (uses default queue)
- [ ] Job status endpoint still works
- [ ] Download endpoint still works
- [ ] Queue position endpoint still works

### Regression Risk: LOW

**Why:**
- No code changes (only deployment config)
- Task routing unchanged
- Queue definitions unchanged
- API unchanged

**Only change**: Which worker processes which queue (infrastructure isolation)

---

## Deployment

### Local (Development)

```bash
# 1. Pull latest changes
git pull origin main

# 2. Stop current services
./dev.sh down

# 3. Start with new worker
./dev.sh up

# 4. Verify 3 workers running
docker ps | grep worker
# Expected: 3 containers (vntyper, vntyper_long, general)

# 5. Test both job types (see Manual Verification above)
```

### Production

```bash
# 1. SSH to server
ssh vntyper.org

# 2. Pull latest
cd /path/to/vntyper-online-backend
git pull origin main

# 3. Build images
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  build

# 4. Start new slow worker (safe - doesn't conflict)
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  up -d backend_worker_vntyper_long

# Wait 10 seconds, verify running
docker ps | grep vntyper_long

# 5. Restart general worker (quick, no jobs lost)
docker-compose --env-file .env.production \
  -f docker-compose.yml -f docker-compose.prod.yml \
  restart backend_worker

# 6. Verify all workers healthy
docker ps | grep worker
docker-compose logs -f | grep "consuming from"

# 7. Submit test jobs (both types)
```

**Downtime**: < 5 seconds (only general worker restart)
**Risk**: Very Low (infrastructure change only)

---

## Rollback

If issues occur:

```bash
# 1. Stop new worker
docker-compose stop backend_worker_vntyper_long
docker-compose rm -f backend_worker_vntyper_long

# 2. Restore general worker to consume all queues
# Edit docker-compose.yml line 64, remove "-Q", "celery"

# 3. Restart general worker
docker-compose restart backend_worker

# 4. Verify
docker ps | grep worker
# Should see 2 workers (original state)
```

**Recovery Time**: < 2 minutes

---

## Documentation Updates

### CLAUDE.md

Add simple note:

```markdown
## Worker Architecture

VNtyper Online uses 3 dedicated Celery workers:

- **backend_worker_vntyper**: Fast jobs (vntyper_queue, concurrency=1)
- **backend_worker_vntyper_long**: Slow jobs (vntyper_long_queue, concurrency=1)
- **backend_worker**: General tasks (celery queue, default concurrency)

This ensures fast jobs never wait for slow jobs to complete.
```

---

## Success Criteria

- [ ] 3 workers running (fast, slow, general)
- [ ] Each worker consumes from correct queue only
- [ ] Normal jobs processed by fast worker only
- [ ] adVNTR jobs processed by slow worker only
- [ ] General tasks processed by general worker only
- [ ] No race conditions
- [ ] All existing functionality works
- [ ] Zero job loss during deployment

---

## Summary

**Problem**: Race condition, no guaranteed fast lane
**Solution**: Add 1 worker, restrict 1 worker
**Changes**: 2 lines in docker-compose.yml
**Code changes**: 0
**Risk**: Very Low
**Benefit**: Guaranteed fast processing for normal mode

**Complexity**: 🟢 Minimal
**SOLID**: ✅ Single Responsibility (each worker, one queue)
**DRY**: ✅ No duplication
**KISS**: ✅ Simplest solution that works
**YAGNI**: ✅ No unnecessary features

**Estimated Time**: 30 minutes (including testing)
