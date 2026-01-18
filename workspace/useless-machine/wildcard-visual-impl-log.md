# Wildcard Visual Mode - Implementation Log

## Overview

Tracking implementation progress for `wildcard-visual.scd` per the spec in `260111-185743-wildcard-visual-spec.md`.

**Start Date:** 2026-01-11
**Status:** In Progress

---

## Milestone 0: API Capability Probing

**Goal:** Verify the Document API actually works as documented.

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 0.1 | Document.current exists | PASS | |
| 0.2 | doc.string readable | PASS | |
| 0.3 | selectionStart/Size | PASS | |
| 0.4 | selectRange works | PASS | |
| 0.5 | selectedString_ replacement | PASS | |
| 0.6 | String.interpret works | PASS | |

### Test Session Log

```
2026-01-11: All 6 tests passed. Document API fully functional on macOS.
```

**Milestone 0 Complete** - Proceeding to Milestone 0.5.

---

## Milestone 0.5: Coordinate System Deep Dive

**Goal:** Understand why `doc.string` positions don't match `doc.selectRange` positions.

**Status:** In Progress

**Test File:** `wildcard-visual-m05-diagnostic.scd` (standalone, minimal)

### The Problem

Initial M1 tests revealed a critical issue:
- `text[29474..29482]` returns `'.........'` (correct)
- `doc.selectRange(29474, 9)` selects `' controll'` (wrong!)

String indexing and Document.selectRange use **different coordinate systems**.

### Hypotheses

1. **Unicode/UTF-8 encoding** - SC strings are byte-based (per docs), but selectRange might use character positions
2. **BOM (Byte Order Mark)** - Hidden header in file
3. **Qt vs SC coordinate systems** - IDE uses Qt internally (likely UTF-16)

### Key Finding from SC Docs

From [SuperCollider String docs](https://doc.sccode.org/Classes/String.html):
> "Because non-ASCII UTF-8 characters consist of two or more bytes, and a SuperCollider String's members are one-bit Chars, concepts of size and indexing may not behave intuitively."

So `String` is byte-indexed, but `Document.selectRange` likely uses character (codepoint) positions.

### Test File Contents

The diagnostic file `wildcard-visual-m05-diagnostic.scd` contains:
- Unicode test chars: → (arrow), 한글 (Korean), 🎹 (emoji)
- A target string `".........."` to find and select
- Tests 0.5a-0.5f to measure drift at various positions

### Test Results

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| 0.5a | Basic sanity at file start | PENDING | |
| 0.5b | Find non-ASCII bytes | PENDING | |
| 0.5c | Drift at various positions | PENDING | |
| 0.5d | Find first mismatch | PENDING | |
| 0.5e | Find and select TARGET_DOTS | PENDING | |
| 0.5f | Reverse lookup | PENDING | |

### Analysis

**Confirmed Finding:** `Document.selectRange` uses UTF-16 code units, `String` indexing uses bytes.

| Char | UTF-8 bytes | UTF-16 units | Drift contribution |
|------|-------------|--------------|-------------------|
| → (U+2192) | 3 | 1 | +2 |
| 한 | 3 | 1 | +2 |
| 글 | 3 | 1 | +2 |
| 🎹 (U+1F3B9) | 4 | 2 (surrogate) | +2 |
| **Total** | 13 | 5 | **+8** |

**Formula:** `bytePosition = utf16Position + cumulativeDrift`

Where drift accumulates as:
- ASCII (U+0000-007F): 1 byte, 1 UTF-16 unit → +0
- U+0080-07FF: 2 bytes, 1 UTF-16 unit → +1
- U+0800-FFFF: 3 bytes, 1 UTF-16 unit → +2
- U+10000-10FFFF: 4 bytes, 2 UTF-16 units (surrogate pair) → +2

**Milestone 0.5 Complete** - Proceeding to Milestone 0.9.

---

## Milestone 0.9: Position Converter Utility

**Goal:** Implement and exhaustively test byte↔UTF-16 position conversion functions.

**Status:** Complete ✓

**Test File:** `wildcard-visual-m09-converter.scd`

### Requirements

1. `byteToUtf16(text, bytePos)` - Convert byte position to UTF-16 position ✓
2. `utf16ToByte(text, utf16Pos)` - Convert UTF-16 position to byte position ✓
3. Must handle all Unicode planes correctly ✓
4. Must be 100% accurate - this is foundational ✓

### Implementation

```supercollider
~utf8ByteLength = {|leadingByte| ... };  // Detect 1/2/3/4 byte sequences
~utf16UnitCount = {|utf8ByteLen| ... };  // 4-byte UTF-8 = 2 UTF-16 units
~byteToUtf16 = {|text, bytePos| ... };   // For use with selectRange
~utf16ToByte = {|text, utf16Pos| ... };  // For string indexing
```

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 0.9a | ASCII-only conversion | PASS | |
| 0.9b | 2-byte UTF-8 chars | PASS | Latin, Greek, Cyrillic |
| 0.9c | 3-byte UTF-8 chars | PASS | Korean, Japanese, arrows |
| 0.9d | 4-byte UTF-8 (emoji) | PASS | Surrogate pairs handled |
| 0.9e | Mixed content | PASS | |
| 0.9f | Round-trip accuracy | PASS | 15 positions verified |
| 0.9g | Python vectors | PASS | 126/126 tests |
| 0.9h | Reverse direction | PASS | 22/22 tests |
| LIVE | Document.selectRange | PASS | 4 markers verified |
| LIVE-R | utf16ToByte accuracy | PASS | 5 positions verified |

**Milestone 0.9 Complete** - Proceeding to Milestone 1.

---

## Milestone 1: Read-Only Document Inspection

**Goal:** Build tooling to find and parse the control panel WITHOUT modifying anything.

**Status:** Complete ✓

**Test File:** `wildcard-visual-m1-inspection.scd`

**Test Target:** `wildcard-visual-test-target.scd` (dedicated fixture file)

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 1.1 | Find known string pattern | PASS | Uses File.readAllString |
| 1.2 | Find dot string within controller | PASS | Extracts dots from `~rev.(` |
| 1.3 | Parse all controllers into registry | PASS | All 7 controllers parsed |
| 1.4 | Verify positions with selectRange | PASS | Byte→UTF-16 conversion verified |

### Key Decisions

- Tests 1.1-1.3 use `File.readAllString` instead of `Document.current` for reliability
- Test 1.4 uses `Document.open(path)` (synchronous) to verify Document API
- Dedicated test target file avoids false positives from pattern matching in test code

**Milestone 1 Complete** - Proceeding to Milestone 1.5.

---

## Milestone 1.5: Cross-File Document Manipulation (Double-Indirection)

**Goal:** Verify that code loaded from one file can correctly find and modify text in other documents.

**Status:** Complete ✓

**Test Files:** `tests/m15/`
- `test-source.scd` - The "orchestrator" that executes loaded code
- `test-changer-logic.scd` - Contains the modification logic (loaded, not executed directly)
- `test-utilities.scd` - Third file to verify cross-file targeting

### Test Cases

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 1.5a | Loaded code modifies test-source.scd | PASS | Changer targets the file that invoked it |
| 1.5b | Loaded code modifies itself (test-changer-logic.scd) | PASS | Self-modification |
| 1.5c | Loaded code modifies third file (test-utilities.scd) | PASS | True cross-file operation |
| 1.5d | Document handle persistence after switch | PASS | Verify handles remain valid |
| 1.5e | Modify document WITHOUT stealing focus | PASS | `selectRange`/`selectedString_` work on background docs |
| 1.5f | Use `Document.allDocuments` to avoid open() | PASS | Can get handles without focus steal |

### Key Findings

- **Yes:** `Document.open(path)` returns existing handle if file is already open
- **Yes:** Can hold multiple Document handles simultaneously
- **Yes:** Modifying a non-current document works without making it "current"
- **Key:** Use `doc.front` to return focus after `Document.open`, then modify in background
- **Key:** `Document.allDocuments` provides handles to open docs without stealing focus

**Milestone 1.5 Complete** - Proceeding to Milestone 2.

---

## Milestone 2: Single Text Replacement

**Status:** Complete ✓

**Prerequisite:** M0.9 converter + M1 registry

**Key change from original spec:** All `selectRange` calls must use `~byteToUtf16` conversion.

### SC IDE Bug Fix (Blocker Resolved)

Surrogate pair replacement was broken due to a bug in SC IDE's `Document.setTextInRange`. Fixed in commit `86238d725`:

```cpp
// Before: movePosition moves by graphemes (wrong for surrogate pairs)
cursor.movePosition(QTextCursor::NextCharacter, QTextCursor::KeepAnchor, range);

// After: setPosition uses UTF-16 code units consistently
cursor.setPosition(start + range, QTextCursor::KeepAnchor);
```

**Requires:** SC IDE built from this branch or with equivalent patch.

### Test Files

- `tests/m2/test-runner.scd` - Test harness with `~replaceController` helper
- `tests/m2/test-target.scd` - Test file with controller patterns

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 2.1 | Basic replacement | PASS | |
| 2.2 | Varying lengths | PASS | |
| 2.3 | Non-dot placeholders | PASS | |
| 2.4 | Empty placeholder | PASS | |
| 2.5 | Spaced placeholder | PASS | |
| 2.6 | Multiline placeholder | PASS | |
| 3.1 | Unicode (BMP) | PASS | arrows, Korean |
| 3.2 | After unicode drift | PASS | |
| 3.3 | Nested parens | PASS | |
| 3.4 | Musical symbols (surrogate pairs) | PASS | Fixed by SC IDE patch |
| ADV 1-5 | Adversarial cases | PASS | |

**Milestone 2 Complete** - Proceeding to Milestone 3.

---

## Milestone 3: Position Tracking After Insertion

**Status:** Complete ✓

**Prerequisite:** M0.9 converter + M1 registry

**Key insight:** After text modification, must re-fetch `doc.string` and rescan byte positions before next operation.

### Implementation

The `~replaceController` helper in `tests/m2/test-runner.scd` demonstrates the pattern:
- Re-fetch `doc.string` at start of each operation
- Re-find pattern position (no caching of stale positions)
- Sequential tests (2.2, 2.3, 3.1) verify this works across multiple replacements

**Milestone 3 Complete** - Covered by M2/M3 test runner.

---

## Milestone 4: Repeated Operations

**Status:** Complete ✓

**Goal:** Handle multiple mutations without accumulating errors.

**Test Files:** `tests/m4/`
- `test-runner.scd` - Test harness with breadcrumb insertion
- `test-target.scd` - Test fixture with multiple controller patterns

### Bug Fix: Signed Byte Handling

Initial test 4.7 (Unicode breadcrumbs) failed because the M4 converter used a simplified `~utf8ByteLength` that didn't handle signed byte values. Bytes > 127 (like emoji leading byte `0xF0`) were interpreted as negative values by `.asInteger`, causing incorrect UTF-16 position calculations.

**Fix:** Updated to use `.ascii` with explicit signed-to-unsigned conversion (matching M09 module):
```supercollider
{ code < 0 } {
    var unsigned = code + 256;
    // ... use unsigned for comparisons
}
```

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 4.1 | 5 sequential replacements | PASS | No breadcrumbs |
| 4.2 | Single breadcrumb + replacement | PASS | Position shift handled |
| 4.3 | 3 breadcrumb+replacement cycles | PASS | |
| 4.4 | END_MARKER integrity | PASS | |
| 4.5 | Reverse order (bottom-to-top) | PASS | Adversarial |
| 4.6 | Adjacent controllers | PASS | No gap between lines |
| 4.7 | Unicode breadcrumb content | PASS | Emoji, CJK, arrows in breadcrumbs |
| 4.8 | First-line controller | PASS | Position 0 boundary |
| 4.9 | Stress test (10 cycles) | PASS | Accumulating drift |
| 4.10 | Minimal breadcrumb (3 bytes) | PASS | Edge case |

**Milestone 4 Complete** - Proceeding to Milestone 4.5.

---

## Milestone 4.5: Cursor Preservation During Same-Document Edits

**Status:** In Progress

**Goal:** Modify document text without disrupting user's cursor position when editing the same document.

**Problem:** `selectRange` + `selectedString_` moves cursor to edit location, disrupting user workflow.

**Test Files:** `tests/m45/`
- `test-runner.scd` - Test harness with API probes and test cases
- `test-target.scd` - Test fixture with controller patterns

### Research Questions

1. Does SC have `setTextInRange` or similar non-cursor-moving API?
   - **Finding:** `setTextInRange` is C++ layer only, not callable from sclang
   - **Finding:** `doc.string(text, start, len)` may exist as setter (testing)
2. Can save/restore `selectionStart`/`selectionSize` work reliably?
   - **Testing:** Probe 4.5.0b in test-runner.scd
3. How to adjust cursor position when replacement changes text length?
   - **Solution:** Calculate `lengthDelta = newValue.size - oldLen`, adjust if cursor was after edit

### Implementation Approach

The `~m45ReplacePreserveCursor` helper:
1. Save `selectionStart` and `selectionSize` before edit
2. Perform the replacement using `selectRange` + `selectedString_`
3. Restore cursor with adjustment based on position relative to edit:
   - **Before edit:** No adjustment needed
   - **After edit:** Adjust by `lengthDelta`
   - **Inside edit region:** Place at end of new content

### API Probes

| Probe | Description | Status | Notes |
|-------|-------------|--------|-------|
| 4.5.0a | doc.string(text, start, len) setter | PENDING | Would avoid cursor movement |
| 4.5.0b | selectionStart save/restore | PENDING | Fallback approach |
| 4.5.0c | Verify edit moves cursor | PENDING | Confirm the problem |

### Test Cases

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 4.5a | Cursor before edit location | PASS | Cursor stays in place |
| 4.5b | Cursor after edit location | PASS | Adjusted for length change |
| 4.5c | Cursor inside edit region | PASS | Placed at end of new content |
| 4.5d | Active selection preserved | PASS | Selection size maintained |

### Bugs Fixed

- **Probe 4.5.0c paren-finding bug**: Used `text.find(")")` which found first `)` in comments instead of matching close paren. Fixed by using paren-depth counting.
- **Test 4.5b scoping bug**: `block` construct didn't allow inner assignments to affect outer scope. Rewrote without `block`.

**Milestone 4.5 Complete** - Proceeding to Milestone 4.6.

---

## Milestone 4.6: Async Cross-File Mutation (Observational Test)

**Status:** In Progress

**Goal:** Verify that an async background process can mutate a document while the user is actively editing it, without visibly stealing cursor focus.

**Problem:** M4.5 tests cursor preservation within a single execution context. The real wildcard scenario involves a background Routine mutating the same file the user is focused on.

**Test File:** `tests/m46/test-workspace.scd`

### Key Insight

This test **cannot be fully automated**. The user must observe whether their cursor visibly jumps when the async mutation fires. Programmatic checks may miss visual cursor jumps.

### Test Structure

Single file containing both mutation targets and test code:

```
tests/m46/test-workspace.scd
├── [TOP] Controller patterns (~alpha, ~beta, ~gamma, ~delta) - mutation targets
├── [MIDDLE] Padding text (10+ lines)
├── [SETUP] Utility functions block (run first)
└── [BOTTOM] Test blocks that user executes - cursor stays here
```

### Test Flow

1. User opens `tests/m46/test-workspace.scd`
2. User runs the SETUP block to load utilities
3. User places cursor inside the TEST BLOCK section (bottom)
4. User executes a test block
5. Mutations fire after delays via `fork(AppClock)`
6. User **observes** whether cursor visibly jumps
7. User self-reports: cursor stayed = PASS, cursor jumped = FAIL

### Test Cases

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| Main | 4 mutations at 1s intervals | PENDING | ~alpha, ~beta, ~gamma, ~delta |
| 4.6a | Single async mutation | PENDING | 2s delay, ~alpha only |
| 4.6b | Rapid mutations (stress) | PENDING | 10 mutations, 0.3s apart |

### Implementation Notes

- Uses `~m46ReplacePreserveCursor` helper (adapted from M4.5)
- All mutations use `fork(AppClock)` for async scheduling
- Includes RESET block to restore original controller values

---

## Milestone 5: Integration with Wildcard

**Status:** In Progress

---

## Milestone 6: Error Handling & Recovery

**Status:** Not Started

---

## Milestone 7: Async Cross-File Mutations

**Goal:** Decouple mutation timing from trigger - scheduled/routine-based cross-file modifications.

**Status:** Not Started

**Prerequisite:** M1.5 (cross-file basics) + M4 (repeated operations)

### Key Concepts

- Mutations run on a Routine, not triggered synchronously
- Random timing between mutations
- Multiple mutations can queue/overlap
- Clean shutdown of async processes

### Test Cases

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 7.1 | Single delayed mutation | PENDING | fork { 1.wait; mutate } |
| 7.2 | Repeated mutations on schedule | PENDING | loop { mutate; rrand(0.5, 2).wait } |
| 7.3 | Random target selection | PENDING | Pick file/controller randomly each iteration |
| 7.4 | Graceful stop | PENDING | Stop routine without leaving corrupt state |

---

## Milestone 8: Reactive/Watching Mode

**Goal:** Process watches for user changes and responds - with feedback loop control.

**Status:** Not Started

**Prerequisite:** M7 (async patterns)

### Key Concepts

- Detect when user modifies watched file
- Respond to user changes (echo, transform, propagate)
- Prevent infinite loops (change → react → change → react...)
- Optional: controlled feedback loops for intentional effects

### Test Cases

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 8.1 | Detect user edit | PENDING | Poll-based or callback-based detection |
| 8.2 | Single response to change | PENDING | User edits A → system modifies B |
| 8.3 | Loop prevention | PENDING | Debounce, ignore own changes, or generation counter |
| 8.4 | Controlled feedback | PENDING | Intentional N-iteration feedback then stop |

### Open Questions

- What's the detection mechanism? (polling `doc.string` vs callbacks if available)
- How to distinguish user changes from our changes?
- Rate limiting strategy for rapid user edits

---

## Decisions & Notes

- M0.5 discovery: `String` uses byte indexing, `Document.selectRange` uses UTF-16 code units
- M0.9 solution: `~byteToUtf16` and `~utf16ToByte` converter functions
- All milestones M1+ must use converter for accurate position handling

## Issues Encountered

- Test false positives when `text.find()` matches duplicate strings earlier in file
- Solution: search from expected position or compare text at position directly

## Next Steps

1. ✓ M0: API Capability Probing
2. ✓ M0.5: Coordinate System Discovery
3. ✓ M0.9: Position Converter Utility
4. ✓ M1: Read-Only Document Inspection
5. ✓ M1.5: Cross-File Document Manipulation
6. ✓ M2: Single Text Replacement
7. ✓ M3: Position Tracking After Insertion
8. ✓ M4: Repeated Operations
9. ✓ M4.5: Cursor Preservation (COMPLETE)
10. → M4.6: Async Mutation Observational Test (NEXT)
11. → M5: Integration with Wildcard (BLOCKED on M4.6)
12. M6: Error Handling & Recovery
13. M7: Async Cross-File Mutations
14. M8: Reactive/Watching Mode
