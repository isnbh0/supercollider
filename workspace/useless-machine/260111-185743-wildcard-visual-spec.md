# Wildcard Visual Mode Spec

## Overview

Extend wildcard.scd to visually update the control panel section of soundtest.scd (lines ~800-860) in real-time, then execute the modified code. This creates a "possessed IDE" effect where the user sees dot controllers changing autonomously.

## Goals

1. Mutations modify visible source code in the IDE
2. Modified code blocks auto-execute after text replacement
3. User can watch chaos unfold in real-time
4. Maintains compatibility with existing runtime-only mode

## Target Region

The control panel in soundtest.scd (~L817-870):

```supercollider
( ~rev.(
    "........."
))

( ~speed.(
    "....."
))

( ~jitter.(
    "...."
))
```

## API Research Summary

### Document Manipulation

| Method | Purpose |
|--------|---------|
| `Document.current` | Get active document |
| `selectedString_(text)` | Replace selection with text |
| `selectRange(start, length)` | Select character range |
| `selectionStart` | Get cursor position |
| `string` | Get full document text |
| `getText(start, range)` | Get text at position |

### Code Execution

| Method | Purpose |
|--------|---------|
| `"code".interpret` | Compile and execute string |
| `"code".interpretPrint` | Execute and print result |

### Reference Implementation

ddwSnippets Quark (jamshark70) uses:
```supercollider
doc = Document.current;
doc.selectedString_(snippetText);
doc.selectRange(pos, length);
```

## Architecture

### New Files

```
projects/glitch-workshop/
├── soundtest.scd          # existing
├── wildcard.scd           # existing (modify)
└── wildcard-visual.scd    # new: visual mode extension
```

### Mode Toggle

```supercollider
~wildcardVisualMode = false;  // default: runtime-only (current behavior)
~wildcardVisualMode = true;   // visual: modify source + execute
```

### Core Functions

#### 1. Document Scanner

Find and parse control panel region:

```supercollider
~visualFindControlPanel = {
    var doc = Document.current;
    var text = doc.string;
    var startMarker = "// ==================== CONTROLS ====================";
    var endMarker = "// ==================== ADJUSTMENTS ====================";
    var startPos = text.find(startMarker);
    var endPos = text.find(endMarker);

    if(startPos.isNil or: endPos.isNil, {
        "ERROR: Control panel markers not found".postln;
        ^nil;
    });

    (start: startPos, end: endPos, text: text[startPos..endPos]);
};
```

#### 2. Dot Controller Registry

Map controllers to their document positions:

```supercollider
~visualControllers = IdentityDictionary[
    \rev -> (
        pattern: "~rev.(",
        minDots: 0,
        maxDots: 10,
        lineOffset: nil,  // populated by scanner
        dotStart: nil,
        dotEnd: nil,
    ),
    \speed -> (
        pattern: "~speed.(",
        minDots: 0,
        maxDots: 10,
        lineOffset: nil,
        dotStart: nil,
        dotEnd: nil,
    ),
    // ... etc
];
```

#### 3. Dot String Generator

```supercollider
~visualMakeDots = {|count|
    String.fill(count, $.);
};
```

#### 4. Controller Updater

```supercollider
~visualUpdateController = {|name, dotCount|
    var doc = Document.current;
    var info = ~visualControllers[name];
    var newDots = ~visualMakeDots.(dotCount.clip(info.minDots, info.maxDots));
    var code;

    if(info.dotStart.isNil, {
        "ERROR: Controller % not scanned".format(name).postln;
        ^nil;
    });

    // Method 1: Direct text replacement + interpret
    code = "( ~" ++ name ++ ".(\"" ++ newDots ++ "\"))";
    code.interpret;

    // Method 2: Visual update (modify document text)
    if(~wildcardVisualMode, {
        doc.selectRange(info.dotStart, info.dotEnd - info.dotStart);
        doc.selectedString_(newDots);
    });

    name ++ ": " ++ newDots;
};
```

#### 5. Pattern Finder

Locate dot strings within controller blocks:

```supercollider
~visualScanController = {|name|
    var doc = Document.current;
    var text = doc.string;
    var info = ~visualControllers[name];
    var patternPos = text.find(info.pattern);
    var searchStart, quoteStart, quoteEnd;

    if(patternPos.isNil, { ^nil });

    // Find the dot string: look for "......" after pattern
    searchStart = patternPos + info.pattern.size;
    quoteStart = text.find("\"", offset: searchStart);
    quoteEnd = text.find("\"", offset: quoteStart + 1);

    if(quoteStart.notNil and: quoteEnd.notNil, {
        info.dotStart = quoteStart + 1;
        info.dotEnd = quoteEnd;
        info.currentDots = text[info.dotStart..info.dotEnd - 1];
    });

    info;
};
```

## Mutation Integration

### Modified Jitter Mutation

```supercollider
~wildcardJitterVisual = {
    var newJitter = rrand(0.1, 0.5);
    var dotCount = (newJitter * 10).round.asInteger;  // 0-10 dots for 0-1 range

    // Runtime update (always)
    ~playheadJitter = newJitter;

    // Visual update (if enabled)
    if(~wildcardVisualMode, {
        ~visualUpdateController.(\jitter, dotCount);
    });

    ~wildcardSpam.(">>> WILDCARD 지터: " ++ newJitter.round(0.01) ++ " <<<");
};
```

### Controller Mapping

| Mutation | Controller | Value Range | Dot Range |
|----------|------------|-------------|-----------|
| jitter | `~jitter` | 0.0-0.3 | 0-10 |
| stutter (prob) | N/A | runtime only | - |
| stutter (dur) | N/A | runtime only | - |
| speed | `~speed` | 0-200% | 0-10 |
| reverb | `~rev` | 0.0-1.0 | 0-10 |
| silence | `~silence` | 0.0-0.3 | 0-10 |

## Visual Effects

### Mutation Breadcrumb (WILDCARD WAS HERE)

Every mutation leaves a large, visible comment block above the modified controller. This serves as:
1. **Visual landmark** - User can spot changes while scrolling
2. **Navigation aid** - Cmd+F for "WILDCARD" finds all mutations
3. **Audit trail** - Shows what was changed and when

#### Breadcrumb Format

```supercollider
// ╔══════════════════════════════════════════════════════════════╗
// ║  ██╗    ██╗██╗██╗     ██████╗  ██████╗ █████╗ ██████╗ ██████╗ ║
// ║  ██║    ██║██║██║     ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗║
// ║  ██║ █╗ ██║██║██║     ██║  ██║██║     ███████║██████╔╝██║  ██║║
// ║  ██║███╗██║██║██║     ██║  ██║██║     ██╔══██║██╔══██╗██║  ██║║
// ║  ╚███╔███╔╝██║███████╗██████╔╝╚██████╗██║  ██║██║  ██║██████╔╝║
// ║   ╚══╝╚══╝ ╚═╝╚══════╝╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ║
// ║                    W A S   H E R E                           ║
// ║  mutation: JITTER | value: 0.32 | level: 3                   ║
// ╚══════════════════════════════════════════════════════════════╝
```

#### Compact Alternative (for rapid mutations)

```supercollider
// ▓▓▓ WILDCARD #42 ▓▓▓ JITTER -> 0.32 ▓▓▓ 14:23:07 ▓▓▓
```

#### Breadcrumb Generator

```supercollider
~visualBreadcrumb = {|mutation, value, compact = false|
    var timestamp = Date.localtime.format("%H:%M:%S");
    var count = ~wildcardMutationCount;

    if(compact, {
        "// ▓▓▓ WILDCARD #% ▓▓▓ % -> % ▓▓▓ % ▓▓▓".format(
            count, mutation.asString.toUpper, value.round(0.01), timestamp
        );
    }, {
        [
            "// ╔══════════════════════════════════════════════════════════════╗",
            "// ║  ██╗    ██╗██╗██╗     ██████╗  ██████╗ █████╗ ██████╗ ██████╗ ║",
            "// ║  ██║    ██║██║██║     ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗║",
            "// ║  ██║ █╗ ██║██║██║     ██║  ██║██║     ███████║██████╔╝██║  ██║║",
            "// ║  ██║███╗██║██║██║     ██║  ██║██║     ██╔══██║██╔══██╗██║  ██║║",
            "// ║  ╚███╔███╔╝██║███████╗██████╔╝╚██████╗██║  ██║██║  ██║██████╔╝║",
            "// ║   ╚══╝╚══╝ ╚═╝╚══════╝╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ║",
            "// ║                    W A S   H E R E                           ║",
            "// ║  mutation: % | value: % | level: %                   ║".format(
                mutation.asString.toUpper.padRight(6),
                value.round(0.01).asString.padRight(4),
                ~wildcardLevel
            ),
            "// ╚══════════════════════════════════════════════════════════════╝",
        ].join("\n");
    });
};
```

#### Breadcrumb Insertion

```supercollider
~visualInsertBreadcrumb = {|name, value|
    var doc = Document.current;
    var info = ~visualControllers[name];
    var breadcrumb, insertPos, useCompact;

    // Use compact format at higher chaos levels (too many mutations)
    useCompact = (~wildcardLevel >= 4) or: (~wildcardMutationCount > 20);

    breadcrumb = ~visualBreadcrumb.(name, value, useCompact);

    // Find line start before the controller
    insertPos = info.lineStart ? info.dotStart;  // fallback to dot position

    // Insert breadcrumb + newline before the controller block
    doc.selectRange(insertPos, 0);
    doc.selectedString_(breadcrumb ++ "\n");

    // IMPORTANT: Rescan positions after insertion (text shifted)
    ~visualRescanAfterInsert.(name, breadcrumb.size + 1);
};
```

#### Cleanup Function

```supercollider
// Remove all wildcard breadcrumbs from document
~visualCleanBreadcrumbs = {
    var doc = Document.current;
    var text = doc.string;
    var pattern = "// [▓╔║╚].*WILDCARD.*";  // regex-like pattern

    // Find and remove all breadcrumb blocks
    // Implementation: iterate through matches, remove from end to start
    // (reverse order prevents position shifting issues)

    "Cleaned % breadcrumbs".format(removedCount).postln;
};
```

#### Breadcrumb Settings

```supercollider
~visualBreadcrumbMode = \full;    // \full, \compact, \none
~visualBreadcrumbLimit = 50;      // max breadcrumbs before auto-cleanup
~visualBreadcrumbAutoClean = true; // remove old ones as new ones added
```

### Chaos Text in Document

At higher levels, inject visual chaos into comments:

```supercollider
~visualInjectChaos = {|level|
    var doc = Document.current;
    var chaosComment;

    if(level >= 4, {
        chaosComment = "// " ++ ~chaosString.(30);
        // Insert at specific marker position
        // ...
    });
};
```

### Cursor Animation

Make cursor jump around during mutations:

```supercollider
~visualAnimateCursor = {|targetPos|
    var doc = Document.current;
    doc.selectRange(targetPos, 0);  // Move cursor without selection
};
```

## Execution Flow

```
~wildcardStart.()
    │
    ├── if(~wildcardVisualMode) {
    │       ~visualScanAllControllers.()  // Build position map
    │   }
    │
    └── main loop
            │
            ├── select mutation (jitter, stutter, etc.)
            │
            ├── if(~wildcardVisualMode) {
            │       ~visualUpdateController.(name, value)
            │       // Text changes visible in IDE
            │   }
            │
            └── apply runtime change (always)
```

## Safety

### Document Validation

```supercollider
~visualValidateDocument = {
    var doc = Document.current;
    var path = doc.path;

    // Only modify soundtest.scd
    if(path.notNil and: { path.contains("soundtest.scd") }, {
        true;
    }, {
        "WARNING: Visual mode only works with soundtest.scd open".postln;
        false;
    });
};
```

### Undo Support

Document modifications should be undoable via Cmd+Z. No special handling needed - IDE tracks changes automatically.

## User Interface

### Activation

```supercollider
// In soundtest.scd control section, add:
~wildcardVisualMode = true;   // Enable visual mutations
~wildcardVisualMode = false;  // Runtime-only (default)

// Or toggle function:
~visualToggle = {
    ~wildcardVisualMode = ~wildcardVisualMode.not;
    "Visual mode: " ++ ~wildcardVisualMode;
};
```

### Status Display

```supercollider
~wildcardStatus = {
    // ... existing status ...
    ("Visual mode: " ++ ~wildcardVisualMode).postln;
    if(~wildcardVisualMode, {
        ("Tracked controllers: " ++ ~visualControllers.keys).postln;
    });
};
```

## Platform Considerations

| Platform | Notes |
|----------|-------|
| macOS | IDE may swallow some Cmd keys |
| Windows | Use `getTextAsync` instead of `string` for reliability |
| Linux | Best compatibility with ddwSnippets approach |

## Incremental Implementation & Verification

This is uncharted territory. Each milestone includes standalone test snippets that MUST pass before proceeding.

---

### Milestone 0: API Capability Probing

**Goal:** Verify the Document API actually works as documented.

**Test 0.1: Document.current exists**
```supercollider
// RUN THIS FIRST - does Document.current return something?
(
var doc = Document.current;
if(doc.isNil, {
    "FAIL: Document.current is nil".postln;
}, {
    "PASS: Document.current = %".format(doc).postln;
    "  class: %".format(doc.class).postln;
    "  path: %".format(doc.path).postln;
});
)
```
Expected: Returns a Document object, not nil.

**Test 0.2: Can we read document text?**
```supercollider
(
var doc = Document.current;
var text;

// Try synchronous first
try {
    text = doc.string;
    if(text.isNil, {
        "WARN: doc.string returned nil".postln;
    }, {
        "PASS: doc.string works, length = %".format(text.size).postln;
        "  first 50 chars: %".format(text[0..49].asString).postln;
    });
} { |error|
    "FAIL: doc.string threw: %".format(error).postln;
    "  trying getTextAsync...".postln;
};
)
```
Expected: Returns document contents as string.

**Test 0.3: Can we get selection info?**
```supercollider
(
var doc = Document.current;
"selectionStart: %".format(doc.selectionStart).postln;
"selectionSize: %".format(doc.selectionSize).postln;
)
```
Expected: Returns integers (cursor position).

**Test 0.4: Can we SET a selection range?**
```supercollider
// This should select characters 10-20 in the document
(
var doc = Document.current;
doc.selectRange(10, 10);
"After selectRange(10,10):".postln;
"  selectionStart: %".format(doc.selectionStart).postln;
"  selectionSize: %".format(doc.selectionSize).postln;
)
```
Expected: Selection visibly changes in IDE, values update.

**Test 0.5: Can we REPLACE selected text?**
```supercollider
// WARNING: This WILL modify your document!
// First, manually select some text, then run:
(
var doc = Document.current;
var before = doc.selectedString;
"Before: '%'".format(before).postln;
doc.selectedString_("REPLACED");
"After: '%'".format(doc.selectedString).postln;
"Check document - did it change?".postln;
)
// Cmd+Z to undo
```
Expected: Selected text is replaced with "REPLACED".

**Test 0.6: Can we execute a string?**
```supercollider
(
var code = "1 + 2 + 3";
var result = code.interpret;
"'%'.interpret = %".format(code, result).postln;
if(result == 6, { "PASS".postln }, { "FAIL".postln });
)
```
Expected: Returns 6.

**Milestone 0 Exit Criteria:**
- [x] All 6 tests pass
- [x] Document which tests failed (if any) and on what platform
- [x] If any test fails, STOP and investigate before proceeding

---

### Milestone 0.5: Coordinate System Discovery

**Goal:** Understand why `doc.string` byte positions don't match `doc.selectRange` positions.

**Critical Finding:** SuperCollider uses two different coordinate systems:
- `String` indexing: **UTF-8 bytes**
- `Document.selectRange`: **UTF-16 code units** (Qt's internal representation)

**Drift Calculation:**

| Character Type | UTF-8 bytes | UTF-16 units | Drift contribution |
|---------------|-------------|--------------|-------------------|
| ASCII (U+0000-007F) | 1 | 1 | +0 |
| U+0080-07FF (Latin ext, Greek) | 2 | 1 | +1 |
| U+0800-FFFF (CJK, symbols) | 3 | 1 | +2 |
| U+10000-10FFFF (emoji) | 4 | 2 (surrogate) | +2 |

**Formula:** `bytePosition = utf16Position + cumulativeDrift`

**Example from testing:**
- Arrow → (U+2192): 3 bytes, 1 UTF-16 → +2
- Korean 한글: 6 bytes, 2 UTF-16 → +4
- Emoji 🎹: 4 bytes, 2 UTF-16 → +2
- **Total drift: +8 bytes**

This was verified empirically: `selectRange(527)` selected text found at byte position 535.

---

### Milestone 0.9: Position Converter Utility

**Goal:** Implement and exhaustively test byte↔UTF-16 position conversion.

**Rationale:** All subsequent milestones depend on accurate position conversion. This utility must be 100% correct.

**Required Functions:**

```supercollider
// Convert byte position to UTF-16 position for use with selectRange
~byteToUtf16 = {|text, bytePos| ... };

// Convert UTF-16 position (from selectRange) to byte position for string indexing
~utf16ToByte = {|text, utf16Pos| ... };
```

**Test Strategy:**

Use Python to generate test vectors covering:
1. ASCII-only strings (no drift)
2. 2-byte UTF-8 characters (Latin, Greek, Cyrillic)
3. 3-byte UTF-8 characters (CJK, arrows, math symbols)
4. 4-byte UTF-8 characters (emoji with surrogate pairs)
5. Mixed content
6. Edge cases (empty, single char, boundaries)
7. Round-trip verification: `utf16ToByte(byteToUtf16(x)) == x`

**Test File:** `wildcard-visual-m09-converter.scd`

**Milestone 0.9 Exit Criteria:**
- [x] All Python-generated test vectors pass (126/126)
- [x] Round-trip conversion is identity
- [x] No off-by-one errors at character boundaries
- [x] Handles all 4 UTF-8 byte lengths correctly
- [x] LIVE verification against Document.selectRange passes

---

### Milestone 1: Read-Only Document Inspection

**Goal:** Build tooling to find and parse the control panel WITHOUT modifying anything.

**Prerequisite:** Load converter functions from M0.9 (`wildcard-visual-m09-converter.scd`)

**Test File:** `wildcard-visual-m1-inspection.scd`

**Test 1.1: Find a known string pattern**

Find `~rev.(` or similar controller pattern in the document. Returns byte position.

**Test 1.2: Find the dot string within a controller**

Given a controller pattern, locate the quoted dot string (e.g., `"......."`) and extract:
- Byte position of first dot
- Byte position of closing quote
- The dot string itself

**Test 1.3: Parse all controllers into registry**

Build a registry mapping controller names to their positions:

```supercollider
~m1Registry[\rev] = (
    pattern: "~rev.(",
    byteStart: 1234,      // byte position of first dot
    byteEnd: 1244,        // byte position of closing quote
    currentDots: ".........",
    dotCount: 9,
);
```

**Test 1.4: Verify positions with selectRange**

Critical test using M0.9 converter functions:

```supercollider
// For each controller in registry:
utf16Start = ~byteToUtf16.(text, info.byteStart);
doc.selectRange(utf16Start, info.dotCount);
selected = doc.selectedString;
// Verify: selected == info.currentDots
```

This proves that byte positions can be correctly converted to UTF-16 positions for `selectRange`.

**Milestone 1 Exit Criteria:**
- [ ] Can find all target controllers
- [ ] Position values are accurate (verified by selectRange with converter)
- [ ] No document modifications occurred

---

### Milestone 1.5: Cross-File Document Manipulation (Double-Indirection)

**Goal:** Verify that code loaded from one file can correctly find and modify text in other documents.

**Rationale:** The real wildcard system will load modification logic from one file and execute it to change another. This milestone validates that cross-file Document manipulation works before building on it.

**Test Files:**
- `test-source.scd` - The "orchestrator" that executes loaded code
- `test-changer-logic.scd` - Contains the modification logic (loaded, not executed directly)
- `test-utilities.scd` - Third file to verify cross-file targeting

**Test 1.5a: Loaded code modifies the invoking file**
```supercollider
// In test-source.scd:
// 1. Load test-changer-logic.scd (via File.readAllString + interpret, or thisProcess.interpreter.executeFile)
// 2. Call a function defined there
// 3. That function should find and modify a TARGET marker in test-source.scd
// 4. Verify the modification happened

// test-source.scd contains:
// TARGET_A: "........."

// test-changer-logic.scd defines:
~changeTarget = {|targetFile, marker, newValue|
    var doc = Document.open(targetFile);
    // ... find marker, replace dots ...
};
```

**Test 1.5b: Loaded code modifies itself**
```supercollider
// Code loaded from test-changer-logic.scd modifies test-changer-logic.scd
// This tests self-referential document access
```

**Test 1.5c: Loaded code modifies a third file**
```supercollider
// Code loaded from test-changer-logic.scd modifies test-utilities.scd
// True cross-file operation: invoker ≠ logic source ≠ target
```

**Test 1.5d: Document handle persistence**
```supercollider
// Open handles to all 3 files
// Modify one, verify others still accessible
// Check if Document.open returns same handle for already-open file
```

**Key Questions to Resolve:**
- Does `Document.open(path)` return existing handle if file is already open?
- Can we hold multiple Document handles simultaneously?
- Does modifying a non-current document work without making it "current"?
- Does `Document.allDocuments` give us access to already-open documents?

**Milestone 1.5 Exit Criteria:**
- [ ] Code from file A can modify file B (the invoker)
- [ ] Code from file A can modify file A (self-modification)
- [ ] Code from file A can modify file C (third-party file)
- [ ] Multiple Document handles work simultaneously
- [ ] Position conversion works correctly across different files

---

### Milestone 2: Single Text Replacement

**Goal:** Successfully replace ONE dot string, ONE time.

**Prerequisite:** M0.9 converter functions + M1 registry

**Test 2.1: Replace dots at known position**
```supercollider
// Uses registry from M1 + converter from M0.9
// WARNING: Modifies document!
(
var doc = Document.current;
var text = doc.string;
var info = ~m1Registry[\rev];
var newDots = "..........";  // 10 dots
var utf16Start, len;

if(info.isNil, { "FAIL: No registry for \\rev".postln; ^nil });

len = info.dotCount;
utf16Start = ~byteToUtf16.(text, info.byteStart);  // Convert!

"Replacing % chars at UTF-16 pos % with '%'".format(len, utf16Start, newDots).postln;

doc.selectRange(utf16Start, len);
"Selected: '%'".format(doc.selectedString).postln;

doc.selectedString_(newDots);
"Replaced. Check document!".postln;
)
// Cmd+Z to undo
```

**Test 2.2: Replace AND execute**
```supercollider
(
var newDots = ".....";
var code = "( ~rev.(\"" ++ newDots ++ "\"))";

"Executing: %".format(code).postln;
code.interpret;
"Check: ~genReverb = %".format(~genReverb).postln;
)
```

**Test 2.3: Combined visual + execute**
```supercollider
(
var doc = Document.current;
var text = doc.string;
var info = ~m1Registry[\rev];
var newDots = "...";
var code, utf16Start;

if(info.isNil, { ^nil });

// Visual update (with conversion)
utf16Start = ~byteToUtf16.(text, info.byteStart);
doc.selectRange(utf16Start, info.dotCount);
doc.selectedString_(newDots);

// Execute
code = "( ~rev.(\"" ++ newDots ++ "\"))";
code.interpret;

"Visual + Execute complete. ~genReverb = %".format(~genReverb).postln;
)
```

**Milestone 2 Exit Criteria:**
- [ ] Single replacement works (with byte→UTF-16 conversion)
- [ ] Execute works
- [ ] Combined works
- [ ] Undo (Cmd+Z) works after modification

---

### Milestone 3: Position Tracking After Insertion

**Goal:** Handle the hard problem - positions shift when text is inserted.

**Prerequisite:** M0.9 converter functions + M1 registry

**Key insight:** After any text modification:
1. Byte positions of all subsequent content shift
2. UTF-16 positions also shift
3. Must re-fetch `doc.string` and rescan before next operation

**Test 3.1: Verify position shift problem**
```supercollider
(
var doc = Document.current;
var text1, text2, pos1, pos2;

// Find position of ~jitter (byte position)
text1 = doc.string;
pos1 = text1.find("~jitter.(");
"Before insertion: ~jitter at byte %".format(pos1).postln;

// Insert 20 characters at UTF-16 position 100
doc.selectRange(100, 0);  // Note: 100 is small, likely no drift yet
doc.selectedString_("/* INSERTED TEXT */");

// Find position again
text2 = doc.string;
pos2 = text2.find("~jitter.(");
"After insertion: ~jitter at byte %".format(pos2).postln;
"Byte shift: %".format(pos2 - pos1).postln;
)
// Cmd+Z to undo
```
Expected: Position increases by ~19 characters.

**Test 3.2: Rescan after modification**
```supercollider
// Strategy: rescan ALL byte positions after ANY modification
(
~visualRescanAll = {
    var doc = Document.current;
    var text = doc.string;

    ~m1Registry.keysValuesDo {|name, info|
        var pos = text.find(info.pattern);
        var q1, q2, region;

        if(pos.notNil, {
            region = text[pos..(pos+150).min(text.size-1)];
            q1 = region.find("\"");
            if(q1.notNil, { q2 = region.find("\"", false, q1 + 1) });

            if(q1.notNil and: q2.notNil, {
                info.byteStart = pos + q1 + 1;
                info.byteEnd = pos + q2;
                info.currentDots = text[info.byteStart..info.byteEnd-1];
                info.dotCount = info.currentDots.size;
            });
        });
    };
    "Rescanned % controllers".format(~m1Registry.size).postln;
};

~visualRescanAll.();
)
```

**Test 3.3: Insert breadcrumb then update controller**
```supercollider
(
var doc = Document.current;
var text = doc.string;
var info = ~m1Registry[\rev];
var breadcrumb = "// ▓▓▓ WILDCARD TEST ▓▓▓\n";
var newDots = "........";
var lineStart, utf16Start;

if(info.isNil, { ^nil });

// Find line start (search backwards for newline) - byte position
lineStart = text[0..info.byteStart].findBackwards("\n");
lineStart = if(lineStart.isNil, { 0 }, { lineStart + 1 });

"Inserting breadcrumb at byte pos %".format(lineStart).postln;

// Insert breadcrumb (convert byte→UTF-16 for selectRange)
utf16Start = ~byteToUtf16.(text, lineStart);
doc.selectRange(utf16Start, 0);
doc.selectedString_(breadcrumb);

// CRITICAL: Rescan positions (text changed!)
~visualRescanAll.();

// Now update the dots with fresh positions
text = doc.string;  // Re-fetch!
info = ~m1Registry[\rev];
utf16Start = ~byteToUtf16.(text, info.byteStart);
doc.selectRange(utf16Start, info.dotCount);
doc.selectedString_(newDots);

"Complete. Check document!".postln;
)
// Cmd+Z twice to undo
```

**Milestone 3 Exit Criteria:**
- [ ] Understand position shift behavior
- [ ] Rescan function works reliably (updates byte positions)
- [ ] Converter used correctly with fresh text after each modification
- [ ] Breadcrumb + update works in sequence

---

### Milestone 4: Repeated Operations

**Goal:** Handle multiple mutations without accumulating errors.

**Test 4.1: 5 mutations in sequence**
```supercollider
(
var controllers = [\rev, \jitter, \speed, \rev, \jitter];
var dotCounts = [3, 7, 5, 10, 0];

controllers.do {|name, i|
    var info, newDots, len, doc;

    ~visualRescanAll.();  // Always rescan first
    info = ~testRegistry[name];
    if(info.isNil, {
        "SKIP: % not in registry".format(name).postln;
    }, {
        newDots = String.fill(dotCounts[i], $.);
        doc = Document.current;
        len = info.dotEnd - info.dotStart;

        doc.selectRange(info.dotStart, len);
        doc.selectedString_(newDots);
        "Mutation %: % -> '%'".format(i+1, name, newDots).postln;

        0.1.wait;  // Small delay to let IDE update
    });
};
"5 mutations complete".postln;
)
```

**Test 4.2: Mutation with breadcrumbs**
```supercollider
(
{
    3.do {|i|
        var name = [\rev, \jitter, \speed][i];
        var info, doc, lineStart, breadcrumb, newDots, len;

        ~visualRescanAll.();
        info = ~testRegistry[name];
        if(info.notNil, {
            doc = Document.current;

            // Insert breadcrumb
            lineStart = doc.string[0..info.dotStart].findBackwards("\n") + 1;
            breadcrumb = "// ▓▓▓ WILDCARD #% ▓▓▓ % ▓▓▓\n".format(i+1, name);
            doc.selectRange(lineStart, 0);
            doc.selectedString_(breadcrumb);

            // Rescan and update
            ~visualRescanAll.();
            info = ~testRegistry[name];
            newDots = String.fill(5.rand + 1, $.);
            len = info.dotEnd - info.dotStart;
            doc.selectRange(info.dotStart, len);
            doc.selectedString_(newDots);

            "Mutation % complete".format(i+1).postln;
        });
        0.5.wait;
    };
    "All mutations complete".postln;
}.fork;
)
```

**Milestone 4 Exit Criteria:**
- [ ] Multiple sequential mutations work
- [ ] Breadcrumb insertion doesn't break subsequent operations
- [ ] No position drift over time

---

### Milestone 4.5: Cursor Preservation During Same-Document Edits

**Goal:** Modify document text without disrupting user's cursor position when editing the same document.

**Problem:** Current `selectRange` + `selectedString_` approach moves cursor to the edit location, disrupting user workflow when wildcard mutates a document they're actively editing.

**Research Questions:**
1. Does SC have a direct text replacement API (e.g., `setTextInRange`) that doesn't move cursor?
2. Can we save/restore cursor position reliably?
3. How do we handle cursor position adjustment when replacement changes text length?

**Test 4.5a: Cursor position before edit location**
```supercollider
// User cursor at line 10, edit happens at line 50
// Expected: cursor stays at line 10
```

**Test 4.5b: Cursor position after edit location**
```supercollider
// User cursor at line 50, edit happens at line 10
// Expected: cursor stays at line 50 (adjusted for length change)
```

**Test 4.5c: Cursor inside edit region**
```supercollider
// User cursor inside the controller being mutated
// Expected: reasonable behavior (cursor at end of new content?)
```

**Test 4.5d: User has active selection**
```supercollider
// User has text selected, edit happens elsewhere
// Expected: selection preserved
```

**Potential Solutions:**
1. **Save/restore**: `selectionStart`/`selectionSize` before, restore after (with offset adjustment)
2. **Alternative API**: Check for `setTextInRange` or similar
3. **Defer to idle**: Only mutate when user hasn't typed for N ms

**Milestone 4.5 Exit Criteria:**
- [x] Identify available SC Document APIs for non-cursor-moving edits
- [x] Implement cursor preservation wrapper
- [x] All 4 test cases pass
- [ ] User can type while wildcard mutates without disruption

---

### Milestone 4.6: Async Cross-File Mutation (Observational Test)

**Goal:** Verify that an async background process can mutate a document while the user is actively editing it, without visibly stealing cursor focus.

**Problem:** M4.5 tests cursor preservation within a single execution context. The real wildcard scenario involves a background Routine mutating the same file the user is focused on. We need to verify the user's cursor doesn't visibly jump.

**Key Insight:** This test cannot be fully automated. The user must observe whether their cursor moves when the async mutation fires. Programmatic checks happen in the same execution context and may miss visual cursor jumps.

**Test Structure:**

A single file containing both mutation targets and test code:

```
tests/m46/test-workspace.scd
├── [TOP SECTION] Controller patterns (~alpha, ~beta, etc.)
├── [MIDDLE] Padding text
└── [BOTTOM SECTION] Test block that user executes
```

**Test Flow:**

1. User opens `test-workspace.scd`
2. User places cursor inside the test block (bottom section)
3. User executes the test block
4. Test block schedules async mutations (via `fork`) to the top section
5. Mutations fire after delays (e.g., 1s, 2s, 3s)
6. User **observes** whether their cursor visibly jumps to mutation sites
7. User self-reports: cursor stayed = PASS, cursor jumped = FAIL

**Test Code Pattern:**

```supercollider
// === TEST BLOCK (run this with cursor here) ===
(
"[M4.6] Starting async mutation test...".postln;
"[M4.6] Keep your cursor HERE and watch for jumps!".postln;
{
    3.do { |i|
        (i + 1).wait;
        "[M4.6] Mutation % firing NOW...".format(i + 1).postln;
        ~m46Mutate.(Document.current, "alpha", "MUT" ++ (i + 1));
    };
    "[M4.6] All mutations complete.".postln;
    "[M4.6] Did your cursor stay in this block? PASS/FAIL".postln;
}.fork(AppClock);
)
```

**Why Observational:**
- Programmatic `selectionStart` checks happen in the same context
- The user's experience of "cursor jumped" is what matters for UX
- Visual flicker/jump may not be captured by position checks

**Milestone 4.6 Exit Criteria:**
- [ ] Test file created with controller targets + test block
- [ ] Async mutation helper uses cursor preservation from M4.5
- [ ] User can run test and observe cursor behavior
- [ ] Document results: does cursor stay put during async mutations?

---

### Milestone 5: Integration with Wildcard

**Goal:** Build a minimal wildcard-like system using proven utilities, then integrate into main wildcard.scd.

**Approach:** Standalone test environment in `tests/m5/` that incrementally builds toward full integration.

#### Test Structure

```
tests/m5/
├── utils.scd           # Consolidated utilities from M0.9-M4
├── test-target.scd     # Minimal fixture with controller patterns
├── mini-wildcard.scd   # Tiny chaos engine for testing
└── test-runner.scd     # Integration tests
```

#### Phase 5.1: Utils Module

Consolidate proven code from previous milestones into a clean, loadable module:

```supercollider
// utils.scd - Load with: (thisProcess.nowExecutingPath.dirname +/+ "utils.scd").load

// === UTF-8/UTF-16 CONVERTERS (from M0.9) ===
~utf8ByteLength = {|byte| ... };      // Handles signed bytes
~utf16UnitCount = {|byteLen| ... };   // 4-byte = 2 units (surrogate)
~byteToUtf16 = {|text, bytePos| ... };
~utf16ToByte = {|text, utf16Pos| ... };

// === DOCUMENT HELPERS (from M4) ===
~getDocByFilename = {|filename| ... };  // Find open doc without focus steal
~replaceContent = {|doc, name, value| ... };  // Pattern-based replacement
~insertBefore = {|doc, name, text| ... };     // Insert at line start
~verifyContent = {|doc, name, expected| ... }; // Verification helper
```

#### Phase 5.2: Mini-Wildcard

A stripped-down chaos engine that exercises the visual mutation pattern:

```supercollider
// mini-wildcard.scd - Minimal chaos engine for testing

// === STATE ===
~miniLevel = 1;           // 1-5 chaos intensity
~miniVisualMode = true;   // Toggle visual mutations
~miniRunning = false;
~miniDoc = nil;           // Target document handle

// === MUTATIONS ===
~miniMutations = (
    jitter: { rrand(0.0, 0.3) },
    speed: { rrand(0.5, 2.0) },
    reverb: { rrand(0.0, 1.0) },
);

// === CORE LOOP ===
~miniStart = {
    ~miniDoc = ~getDocByFilename.("test-target.scd");
    ~miniRunning = true;
    ~miniRoutine = {
        while { ~miniRunning } {
            var mutation = ~miniMutations.keys.choose;
            var value = ~miniMutations[mutation].();
            var dots = String.fill((value * 10).asInteger, $.);

            // Visual update
            if (~miniVisualMode) {
                ~replaceContent.(~miniDoc, mutation, dots);
            };

            // Log
            "[MINI] % → %".format(mutation, value.round(0.01)).postln;

            // Wait (faster at higher levels)
            rrand(0.5, 3.0 - (~miniLevel * 0.4)).wait;
        };
    }.fork(AppClock);
};

~miniStop = { ~miniRunning = false };
```

#### Phase 5.3: Test Cases

| Test | Description | Validates |
|------|-------------|-----------|
| 5.1 | Utils load without error | Module structure |
| 5.2 | Single mutation via mini-wildcard | Basic integration |
| 5.3 | 10 mutations in sequence | Position tracking |
| 5.4 | Visual mode toggle | Mode switching |
| 5.5 | Cross-file operation | Document targeting |
| 5.6 | Breadcrumb + mutation | Combined operations |

#### Phase 5.4: Main Wildcard Integration

Once mini-wildcard works, integrate into real `wildcard.scd`:

1. Load utils module at wildcard startup
2. Add `~wildcardVisualMode` toggle (default: false)
3. Modify existing mutation functions to call visual update when enabled
4. Wire up document targeting (soundtest.scd)

```supercollider
// In wildcard.scd - integration pattern
~wildcardJitter = {
    var newJitter = rrand(0.1, 0.5);

    // Runtime (always)
    ~playheadJitter = newJitter;

    // Visual (if enabled)
    if (~wildcardVisualMode == true) {
        var dots = String.fill((newJitter / 0.3 * 10).round.asInteger.clip(0, 10), $.);
        ~replaceContent.(~soundtestDoc, "jitter", dots);
    };

    ~wildcardSpam.(">>> WILDCARD 지터: " ++ newJitter.round(0.01) ++ " <<<");
};
```

**Milestone 5 Exit Criteria:**
- [ ] Utils module loads and all functions work
- [ ] Mini-wildcard runs 10+ mutations without error
- [ ] Visual mode toggle works (on/off)
- [ ] Integration pattern validated in isolated test
- [ ] Ready to port to main wildcard.scd

---

### Milestone 6: Error Handling & Recovery

**Goal:** Graceful failure when things go wrong.

**Failure Scenarios to Handle:**
1. Document.current is nil (no document open)
2. Controller pattern not found (document modified externally)
3. Position out of bounds
4. selectRange fails silently
5. IDE becomes unresponsive

**Test 6.1: Defensive wrapper**
```supercollider
(
~visualSafeUpdate = {|name, newDots|
    var doc, info, len, result;

    // Check document
    doc = Document.current;
    if(doc.isNil, {
        "WARN: No document open".postln;
        ^false;
    });

    // Check document is soundtest
    if(doc.path.isNil or: { doc.path.contains("soundtest").not }, {
        "WARN: Not editing soundtest.scd".postln;
        ^false;
    });

    // Rescan and check registry
    ~visualRescanAll.();
    info = ~testRegistry[name];
    if(info.isNil, {
        "WARN: Controller % not found".format(name).postln;
        ^false;
    });

    // Validate positions
    len = info.dotEnd - info.dotStart;
    if(len < 0 or: { info.dotStart < 0 }, {
        "WARN: Invalid positions for %".format(name).postln;
        ^false;
    });

    // Attempt update
    try {
        doc.selectRange(info.dotStart, len);
        doc.selectedString_(newDots);
        result = true;
    } { |error|
        "ERROR: Update failed: %".format(error).postln;
        result = false;
    };

    result;
};

// Test
~visualSafeUpdate.(\rev, ".....");
)
```

**Milestone 6 Exit Criteria:**
- [ ] Graceful failure messages, no crashes
- [ ] Visual mode auto-disables on repeated failures
- [ ] Recovery path documented

---

### Milestone 7: Async Cross-File Mutations

**Goal:** Decouple mutation timing from trigger - scheduled/routine-based cross-file modifications.

**Prerequisite:** M1.5 (cross-file basics) + M4 (repeated operations)

**Key Concepts:**
- Mutations run on a Routine, not triggered synchronously
- Random timing between mutations
- Multiple mutations can queue/overlap
- Clean shutdown of async processes

**Test 7.1: Single delayed mutation**
```supercollider
(
fork {
    "Mutation scheduled...".postln;
    1.wait;
    ~crossFileModify.(targetPath, \\rev, ".....");
    "Mutation complete".postln;
};
)
```

**Test 7.2: Repeated mutations on schedule**
```supercollider
(
~asyncMutator = fork {
    inf.do {|i|
        var target = [\\rev, \\jitter, \\speed].choose;
        var dots = String.fill(10.rand, $.);
        "Async mutation %: % -> '%'".format(i, target, dots).postln;
        ~crossFileModify.(targetPath, target, dots);
        rrand(0.5, 2.0).wait;
    };
};
)

// Stop with:
~asyncMutator.stop;
```

**Test 7.3: Random target selection**
```supercollider
// Pick file AND controller randomly each iteration
(
~targets = [
    (file: "soundtest.scd", controllers: [\rev, \jitter, \speed]),
    (file: "other.scd", controllers: [\delay, \filter]),
];
// ... random selection logic
)
```

**Test 7.4: Graceful stop**
```supercollider
// Stop routine without leaving corrupt state
// - Complete current mutation before stopping
// - Or rollback partial mutation
// - Release document handles
```

**Milestone 7 Exit Criteria:**
- [ ] Delayed mutations work correctly
- [ ] Repeated async mutations don't accumulate errors
- [ ] Random timing and target selection work
- [ ] Clean shutdown leaves documents in valid state

---

### Milestone 8: Reactive/Watching Mode

**Goal:** Process watches for user changes and responds - with feedback loop control.

**Prerequisite:** M7 (async patterns)

**Key Concepts:**
- Detect when user modifies watched file
- Respond to user changes (echo, transform, propagate)
- Prevent infinite loops (change → react → change → react...)
- Optional: controlled feedback loops for intentional effects

**Test 8.1: Detect user edit**
```supercollider
(
~lastSnapshot = Document.current.string;
~watcher = fork {
    inf.do {
        var current = Document.current.string;
        if(current != ~lastSnapshot, {
            "Change detected!".postln;
            ~lastSnapshot = current;
        });
        0.1.wait;  // Poll interval
    };
};
)
```

**Test 8.2: Single response to change**
```supercollider
// User edits file A → system modifies file B
(
~onChange = {|changedFile|
    if(changedFile == "soundtest.scd", {
        ~crossFileModify.("response.scd", \echo, "USER_CHANGED");
    });
};
)
```

**Test 8.3: Loop prevention**
```supercollider
// Strategy 1: Debounce - ignore changes within N ms of our own writes
// Strategy 2: Generation counter - track "our" changes vs "user" changes
// Strategy 3: Content hash - only react if change is different from what we'd write

(
~ourLastWrite = nil;
~onChange = {|newContent|
    if(newContent != ~ourLastWrite, {
        // This is a user change, react to it
        ~react.(newContent);
    });
};

~react = {|content|
    var response = ~transform.(content);
    ~ourLastWrite = response;  // Remember what we're about to write
    ~writeToDoc.(response);
};
)
```

**Test 8.4: Controlled feedback**
```supercollider
// Intentional N-iteration feedback then stop
(
~feedbackLoop = {|iterations|
    var count = 0;
    ~onChangeWithFeedback = {|content|
        if(count < iterations, {
            count = count + 1;
            "Feedback iteration %/%".format(count, iterations).postln;
            ~mutateAndTrigger.(content);
        }, {
            "Feedback complete, stopping".postln;
        });
    };
};
~feedbackLoop.(5);  // Allow 5 feedback iterations
)
```

**Open Questions:**
- What's the detection mechanism? (polling `doc.string` vs callbacks if available)
- How to distinguish user changes from our changes?
- Rate limiting strategy for rapid user edits
- Can we hook into Document's change notifications (if any exist)?

**Milestone 8 Exit Criteria:**
- [ ] Can detect user edits reliably
- [ ] Single response per user change works
- [ ] Infinite loops are prevented
- [ ] Controlled feedback loops work as designed
- [ ] Performance is acceptable (polling overhead)

---

## Fallback Strategies

If a milestone fails, try these alternatives:

| Problem | Fallback |
|---------|----------|
| `doc.string` unreliable | Use `getTextAsync` with callback |
| `selectRange` doesn't work | Try `doc.select(pos, len)` instead |
| `selectedString_` fails | Try writing to file and reloading |
| Position tracking too fragile | Use markers/anchors instead of absolute positions |
| IDE freezes on rapid updates | Add rate limiting (min 100ms between updates) |
| Platform-specific issues | Detect platform, use platform-specific code paths |

## Debug Tooling

```supercollider
// Add to wildcard-visual.scd
~visualDebug = true;

~visualLog = {|msg|
    if(~visualDebug, { ("VISUAL: " ++ msg).postln });
};

~visualDumpRegistry = {
    "=== VISUAL REGISTRY ===".postln;
    ~testRegistry.keysValuesDo {|k, v|
        "  %: dots=% start=% end=%".format(
            k, v.currentDots.size, v.dotStart, v.dotEnd
        ).postln;
    };
};

~visualTestSelect = {|name|
    var info = ~testRegistry[name];
    if(info.notNil, {
        Document.current.selectRange(info.dotStart, info.dotEnd - info.dotStart);
        "Selected % - check IDE".format(name).postln;
    });
};
```

## Open Questions

1. **Async vs Sync**: Should text updates be synchronous or use `getTextAsync`?
2. **Multi-document**: What if user has multiple documents open?
3. **Scroll behavior**: Should document auto-scroll to show mutations?
4. **Rate limiting**: How fast can we update text without lag?
5. **Undo grouping**: Can multiple mutations be undone as one operation?

## Implementation Checklist

- [x] Milestone 0: API Probing (all 6 tests pass)
- [x] Milestone 0.5: Coordinate System Discovery
- [x] Milestone 0.9: Position Converter Utility
- [x] Milestone 1: Read-only inspection
- [x] Milestone 1.5: Cross-file document manipulation (double-indirection)
- [x] Milestone 2: Single replacement
- [x] Milestone 3: Position tracking
- [x] Milestone 4: Repeated operations
- [x] Milestone 4.5: Cursor preservation (same-document edits)
- [ ] Milestone 4.6: Async mutation observational test
- [ ] Milestone 5: Wildcard integration
- [ ] Milestone 6: Error handling
- [ ] Milestone 7: Async cross-file mutations
- [ ] Milestone 8: Reactive/watching mode

**Rule: Do not proceed to Milestone N+1 until Milestone N is complete and verified.**

## References

- [Document class docs](https://doc.sccode.org/Classes/Document.html)
- [String.interpret](https://doc.sccode.org/Classes/String.html)
- [ddwSnippets source](https://github.com/jamshark70/ddwSnippets/blob/master/ddwSnippets.sc)
- [GitHub Issue #646](https://github.com/supercollider/supercollider/issues/646) - Text insertion API discussion
