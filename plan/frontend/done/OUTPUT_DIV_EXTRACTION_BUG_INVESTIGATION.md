# Output Div Extraction Bug - Investigation & Fix Plan

**Date:** 2025-10-22
**Issue:** Output div placeholder message not cleared after BAM extraction, no assembly detection message shown
**Severity:** High - Poor UX, confusing to users
**Frontend Version:** 0.61.0 (localhost) vs 0.32.1 (production)

---

## Executive Summary

After running "Extract Region" on BAM files, the output div shows download buttons but retains the placeholder message "Your results will appear here after job submission." Production correctly replaces this with assembly detection info and a loading spinner during processing.

---

## Investigation Results

### Playwright Testing

**Test Environment:** http://localhost:3000/
**Test Files:**
- `/mnt/c/development/hassansaei/VNtyper/tests/data/example_b178_hg19_subset.bam`
- `/mnt/c/development/hassansaei/VNtyper/tests/data/example_b178_hg19_subset.bam.bai`

**Screenshots:**
- `localhost-output-div-bug.png` - Shows placeholder + download buttons coexisting
- `production-output-div-correct.png` - Shows proper assembly message

### Behavior Comparison

| Aspect | Production (v0.32.1) ✅ | Localhost (v0.61.0) ❌ |
|--------|------------------------|------------------------|
| On "Extract Region" click | Placeholder replaced with loading spinner + "Next poll in: X seconds" | Placeholder remains unchanged |
| During extraction | Loading spinner shows, countdown updates | No visual feedback |
| On completion | Shows "Detected reference assembly: HG19. Please confirm or select manually." | Placeholder "Your results will appear here after job submission." stays |
| Download buttons | Appear below assembly message | Appear below placeholder |
| Assembly dropdown | Auto-selected to detected assembly (hg19) | Remains on "Guess assembly" |

### DOM Structure Analysis

**Production (Correct):**
```yaml
- generic [ref=e35]:  # Output div
  - generic [ref=e91]: "Detected reference assembly: HG19. Please confirm or select manually."
  - generic [ref=e92]:  # Download buttons container
    - link "Download subset_example_b178_hg19_subset.bam"
    - link "Download subset_example_b178_hg19_subset.bam.bai"
```

**Localhost (Buggy):**
```yaml
- generic [ref=e37]:  # Output div container
  - generic [ref=e38]: "Your results will appear here after job submission."  # ❌ PLACEHOLDER STAYS
  - generic [ref=e487]:  # Download buttons container
    - link "Download subset_example_b178_hg19_subset.bam"
    - link "Download subset_example_b178_hg19_subset.bam.bai"
```

### Log Analysis

**Extraction completed successfully:**
```
[09:42:17] [Success] ✅ Processing complete for example_b178_hg19_subset.bam (Fast mode)
[09:42:17] [Info] Extract button re-enabled and text reset to 'Extract Region'.
[09:42:17] [Debug] [ExtractionController] Emitting event: extraction:complete
[09:42:17] [Info] [AppController] Handling extraction complete
[09:42:17] [Info] [AppController] Creating download UI for local extraction
[09:42:17] [Info] Created Blob URL (3.11MB): subset_example_b178_hg19_subset.bam
[09:42:17] [Info] Created Blob URL (0.93MB): subset_example_b178_hg19_subset.bam.bai
[09:42:17] [Success] [AppController] Download UI created successfully
```

**Assembly detection worked:**
```
[09:41:52] [Success] Assembly: hg19
[09:41:52] [Success] Confidence: HIGH
[09:41:52] [Info] Auto-detected assembly: hg19
[09:41:52] [Info] Region to extract: chr1:155158000-155163000
```

---

## Root Cause Analysis

### Primary Issue: AppController.handleExtractionComplete()

The `handleExtractionComplete` method in AppController is not properly managing the output div content:

**Current behavior (v0.61.0):**
- Appends download buttons to output div WITHOUT clearing existing content
- Does not display assembly detection message
- Does not show loading spinner during extraction

**Expected behavior (v0.32.1):**
- Clears output div before adding new content
- Shows assembly detection message: "Detected reference assembly: {ASSEMBLY}. Please confirm or select manually."
- Updates assembly dropdown to detected assembly
- Shows loading spinner and polling countdown during extraction

### Code Location

**File:** `/frontend/resources/js/controllers/AppController.js`
**Method:** `handleExtractionComplete` (approximate line 450-500)

### Event Flow

1. User clicks "Extract Region" button
2. `AppController` triggers extraction via `ExtractionController`
3. `ExtractionController` emits `extraction:complete` event with:
   ```javascript
   {
     pair: { bam: File, bai: File },
     result: {
       subsetBamAndBaiBlobs: { bamBlob: Blob, baiBlob: Blob },
       detectedAssembly: "hg19",
       region: "chr1:155158000-155163000"
     }
   }
   ```
4. `AppController.handleExtractionComplete` receives event
5. **BUG HERE:** Downloads are created but output div is not cleared/updated properly

---

## Fix Plan

### Step 1: Locate handleExtractionComplete Method

**File:** `/frontend/resources/js/controllers/AppController.js`

**Search for:**
- Method handling `extraction:complete` event
- Code creating download buttons for extraction results
- RegionOutput div manipulation

### Step 2: Implement Fix

**Required changes:**

1. **Clear output div content** before adding new elements:
   ```javascript
   const regionOutputDiv = document.getElementById('regionOutput');
   if (regionOutputDiv) {
       regionOutputDiv.innerHTML = ''; // Clear placeholder
   }
   ```

2. **Add assembly detection message:**
   ```javascript
   const assemblyMessage = document.createElement('div');
   assemblyMessage.className = 'alert alert-info';
   assemblyMessage.textContent = `Detected reference assembly: ${detectedAssembly.toUpperCase()}. Please confirm or select manually.`;
   regionOutputDiv.appendChild(assemblyMessage);
   ```

3. **Update assembly dropdown** to detected assembly:
   ```javascript
   const assemblySelect = document.getElementById('referenceAssembly');
   if (assemblySelect && detectedAssembly) {
       const normalizedAssembly = detectedAssembly.toLowerCase();
       const option = Array.from(assemblySelect.options).find(opt =>
           opt.value.toLowerCase() === normalizedAssembly
       );
       if (option) {
           assemblySelect.value = option.value;
       }
   }
   ```

4. **Then append download buttons** as currently done

### Step 3: Add Loading State (Optional Enhancement)

**During extraction:**
```javascript
// When extraction starts
const regionOutputDiv = document.getElementById('regionOutput');
regionOutputDiv.innerHTML = `
    <div class="spinner-border" role="status">
        <span class="sr-only">Loading...</span>
    </div>
    <div>Processing extraction...</div>
`;
```

This matches production behavior but may not be critical for initial fix.

### Step 4: Testing Strategy

**Test with Playwright:**
1. Navigate to http://localhost:3000/
2. Upload BAM/BAI pair (example_b178_hg19_subset.bam)
3. Click "Extract Region"
4. Verify:
   - ✅ Placeholder message disappears
   - ✅ Assembly message appears: "Detected reference assembly: HG19..."
   - ✅ Assembly dropdown updated to hg19
   - ✅ Download buttons appear
   - ✅ No duplicate/overlapping content

**Test with multiple files:**
- Different assemblies (hg19, hg38, GRCh37, GRCh38)
- Multiple BAM pairs in sequence
- Reset button after extraction

**Manual testing:**
- Verify download links work
- Verify extraction can be run again
- Verify reset clears everything

### Step 5: Code Quality

**Follow existing patterns:**
- Use `this._log()` for debugging
- Use `this.emit()` for event communication
- Maintain consistent error handling
- Add JSDoc comments if adding new methods

**Keep SoC principles:**
- AppController orchestrates UI updates
- ExtractionController handles BAM processing
- Don't duplicate logic

### Step 6: Regression Testing

Run full test suite:
```bash
cd frontend
npm run test:run
```

Expected: 536/546 tests passing (10 pre-existing failures in unmappedExtraction and pollingManager)

### Step 7: Version Bump & Commit

1. Update `frontend/package.json`: `0.61.0` → `0.62.0`
2. Update `frontend/resources/js/version.js`:
   ```javascript
   const frontendVersion = '0.62.0'; // Fixed output div to show assembly detection message and clear placeholder after extraction
   ```
3. Commit with message:
   ```
   fix(frontend): clear output div placeholder and show assembly detection message after extraction (v0.62.0)

   - Clear regionOutput div before showing extraction results
   - Display assembly detection message matching production behavior
   - Update assembly dropdown to detected assembly
   - Fixes issue where placeholder "Your results will appear here..." remained visible

   Tested with Playwright on example_b178_hg19_subset.bam
   Production comparison: https://vntyper.org/
   ```

---

## Expected Outcome

After fix, localhost should behave identically to production:

1. ✅ Placeholder clears when extraction starts
2. ✅ Assembly detection message displays on completion
3. ✅ Assembly dropdown auto-updates
4. ✅ Download buttons appear in clean UI
5. ✅ No confusing duplicate messages

---

## Code Files to Modify

1. **Primary:** `/frontend/resources/js/controllers/AppController.js`
   - Modify `handleExtractionComplete` method

2. **Version files:**
   - `/frontend/package.json` (version bump)
   - `/frontend/resources/js/version.js` (version + description)

---

## Potential Risks

**Low risk fix:**
- Only modifying output div content (cosmetic)
- Not changing extraction logic or data flow
- Download functionality already working
- Assembly detection already working

**Mitigations:**
- Test with Playwright before committing
- Compare side-by-side with production
- Run full test suite
- Test reset button functionality

---

## Timeline

- **Investigation:** ✅ Complete (30 mins with Playwright)
- **Writing plan:** ✅ Complete (20 mins)
- **Implementation:** Estimated 15 mins
- **Testing:** Estimated 10 mins
- **Commit:** Estimated 5 mins

**Total:** ~1 hour from start to commit

---

## Notes

- Production (v0.32.1) has correct implementation - use as reference
- This bug was introduced sometime between v0.32.1 and v0.61.0
- Root cause: output div content management in extraction flow
- Assembly detection logic is working correctly (logs confirm)
- Download button creation is working correctly
- Only UI display/clearing logic is broken

---

## References

- Screenshots: `.playwright-mcp/localhost-output-div-bug.png`, `.playwright-mcp/production-output-div-correct.png`
- Test files: `/mnt/c/development/hassansaei/VNtyper/tests/data/example_b178_hg19_subset.bam*`
- Production URL: https://vntyper.org/
- Frontend repo: https://github.com/berntpopp/vntyper-online-frontend.git
