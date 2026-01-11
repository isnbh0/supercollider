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

**Status:** In Progress

**Test File:** `wildcard-visual-m09-converter.scd`

### Requirements

1. `byteToUtf16(text, bytePos)` - Convert byte position to UTF-16 position
2. `utf16ToByte(text, utf16Pos)` - Convert UTF-16 position to byte position
3. Must handle all Unicode planes correctly
4. Must be 100% accurate - this is foundational

### Test Strategy

Use Python to generate edge case test vectors:
- ASCII-only strings
- Mixed ASCII + 2-byte UTF-8 (Latin, Greek, Cyrillic)
- Mixed ASCII + 3-byte UTF-8 (CJK, arrows, symbols)
- Strings with 4-byte UTF-8 (emoji, surrogate pairs)
- Boundary conditions (start, end, mid-character)
- Large position values

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 0.9a | ASCII-only conversion | PENDING | |
| 0.9b | 2-byte UTF-8 chars | PENDING | |
| 0.9c | 3-byte UTF-8 chars | PENDING | |
| 0.9d | 4-byte UTF-8 (emoji) | PENDING | |
| 0.9e | Mixed content | PENDING | |
| 0.9f | Round-trip accuracy | PENDING | |
| 0.9g | Edge cases from Python | PENDING | |

---

## Milestone 1: Read-Only Document Inspection

**Goal:** Build tooling to find and parse the control panel WITHOUT modifying anything.

**Status:** In Progress

### Test Results

| Test | Description | Status | Notes |
|------|-------------|--------|-------|
| 1.1 | Find known string pattern | PENDING | |
| 1.2 | Find dot string within controller | PENDING | |
| 1.3 | Parse all controllers into registry | PENDING | |
| 1.4 | Verify positions with selectRange | PENDING | |

---

## Milestone 2: Single Text Replacement

**Status:** Not Started

---

## Milestone 3: Position Tracking After Insertion

**Status:** Not Started

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

## Decisions & Notes

-

## Issues Encountered

-

## Next Steps

1. Run Milestone 0 tests in SuperCollider IDE
2. Record all results in this log
3. Proceed to Milestone 1 only after all M0 tests pass
