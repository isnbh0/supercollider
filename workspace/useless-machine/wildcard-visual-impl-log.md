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

**Status:** Not Started

**Test Files:**
- `test-source.scd` - The "orchestrator" that executes loaded code
- `test-changer-logic.scd` - Contains the modification logic (loaded, not executed directly)
- `test-utilities.scd` - Third file to verify cross-file targeting

### Test Cases

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 1.5a | Loaded code modifies test-source.scd | PENDING | Changer targets the file that invoked it |
| 1.5b | Loaded code modifies itself (test-changer-logic.scd) | PENDING | Self-modification |
| 1.5c | Loaded code modifies third file (test-utilities.scd) | PENDING | True cross-file operation |
| 1.5d | Document handle persistence after switch | PENDING | Verify handles remain valid |

### Key Questions to Resolve

- Does `Document.open(path)` return existing handle if file is already open?
- Can we hold multiple Document handles simultaneously?
- Does modifying a non-current document work without making it "current"?

---

## Milestone 2: Single Text Replacement

**Status:** Not Started

**Prerequisite:** M0.9 converter + M1 registry

**Key change from original spec:** All `selectRange` calls must use `~byteToUtf16` conversion.

---

## Milestone 3: Position Tracking After Insertion

**Status:** Not Started

**Prerequisite:** M0.9 converter + M1 registry

**Key insight:** After text modification, must re-fetch `doc.string` and rescan byte positions before next operation.

---

## Milestone 4: Repeated Operations

**Status:** Not Started

---

## Milestone 5: Integration with Wildcard

**Status:** Not Started

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
5. → M1.5: Cross-File Document Manipulation (NEXT)
6. M2: Single Text Replacement
7. M3: Position Tracking After Insertion
8. M4: Repeated Operations
9. M5: Integration with Wildcard
10. M6: Error Handling & Recovery
11. M7: Async Cross-File Mutations
12. M8: Reactive/Watching Mode
