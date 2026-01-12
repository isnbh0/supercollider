# SuperCollider IDE Bug: selectedString_ Corrupts Content Around Surrogate Pairs

**Date:** 2026-01-13
**Severity:** High
**Affects:** SuperCollider IDE (scide)
**File:** `editors/sc-ide/core/doc_manager.cpp:383`

## Summary

When using `Document.selectedString_` to replace text containing non-BMP Unicode characters (emoji, musical symbols, etc.), the replacement operation deletes more characters than intended, causing content corruption. Specifically, characters immediately following the selection are "eaten."

## Root Cause

The bug is in `Document::setTextInRange()` in the SC IDE C++ code:

```cpp
// File: editors/sc-ide/core/doc_manager.cpp, line 372-386
void Document::setTextInRange(const QString text, int start, int range) {
    QTextCursor cursor = QTextCursor(mDoc);
    int size = mDoc->characterCount();
    if (start > (size - 1)) {
        start = size - 1;
        range = 0;
    }
    cursor.setPosition(start, QTextCursor::MoveAnchor);
    if (range == -1) {
        cursor.movePosition(QTextCursor::End, QTextCursor::KeepAnchor, 1);
    } else {
        cursor.movePosition(QTextCursor::NextCharacter, QTextCursor::KeepAnchor, range);  // BUG HERE
    }
    cursor.insertText(text);
}
```

**The problem:** Line 383 uses `QTextCursor::NextCharacter` which moves by **Unicode codepoints (characters)**, not **UTF-16 code units**.

- `cursor.setPosition(start)` uses UTF-16 code unit positions (correct)
- `cursor.movePosition(NextCharacter, ..., range)` interprets `range` as character count (incorrect)

For non-BMP Unicode characters (surrogate pairs):
- 1 emoji = 1 codepoint = **2 UTF-16 code units**

When the sclang side passes `range = 4` (for 2 emoji = 4 UTF-16 code units), the IDE interprets this as "move 4 characters forward," which overshoots the intended selection.

## Example

Original content:
```
~emoji.(🎹🎹);
~musical.(𝄞𝄞𝄞);
```

Attempting to replace `🎹🎹` with `0.3`:
- `selectRange(705, 4)` correctly selects the 2 emoji (4 UTF-16 code units)
- `selectedString_("0.3")` is called
- IDE's `setTextInRange` receives `start=705, range=4`
- `movePosition(NextCharacter, ..., 4)` moves 4 **characters** forward:
  1. 🎹 (1 character)
  2. 🎹 (1 character)
  3. `)` (1 character)
  4. `;` (1 character)
- Result: `🎹🎹);` is replaced instead of just `🎹🎹`

Corrupted result:
```
~emoji.(0.3
~musical.(𝄞𝄞𝄞);
```

The `);` and newline are eaten!

## Additional Observations

1. **`doc.isEdited` returns `false`** after the operation, suggesting the IDE doesn't properly track modifications involving surrogate pairs.

2. **Two buffers diverge:** The sclang text mirror (`doc.string`) shows correct content immediately after replacement, but the QTextDocument (which gets saved to disk) is corrupted. This suggests the sclang-side primitive `_ScIDE_SetDocTextMirror` uses different logic than the IDE-side `setTextInRange`.

3. **Corruption cascades:** The musical symbols (𝄞) on subsequent lines also show temporary corruption in debug output, likely due to byte position shifts.

## Proposed Fix

Replace the buggy `movePosition` with `setPosition`:

```cpp
void Document::setTextInRange(const QString text, int start, int range) {
    QTextCursor cursor = QTextCursor(mDoc);
    int size = mDoc->characterCount();
    if (start > (size - 1)) {
        start = size - 1;
        range = 0;
    }
    cursor.setPosition(start, QTextCursor::MoveAnchor);
    if (range == -1) {
        cursor.movePosition(QTextCursor::End, QTextCursor::KeepAnchor, 1);
    } else {
        // FIX: Use setPosition with UTF-16 code unit arithmetic
        // instead of movePosition which counts codepoints
        cursor.setPosition(start + range, QTextCursor::KeepAnchor);
    }
    cursor.insertText(text);
}
```

## Minimal Reproduction

### Step 1: Create test file

Save this as `emoji-test.scd`:
```
ABC🎹🎹XYZ
```

### Step 2: Open and run reproduction code

```supercollider
// Open the test file
~doc = Document.open("/path/to/emoji-test.scd");

// Select the two emoji using UTF-16 positions
// "ABC" = 3 chars, emoji start at position 3
// Two emoji = 4 UTF-16 code units (2 surrogate pairs)
~doc.selectRange(3, 4);

// Verify selection is correct
~doc.selectedString.postln;  // Should print: 🎹🎹

// Replace - THIS CORRUPTS THE DOCUMENT
~doc.selectedString_("NEW");

// Check result
~doc.string.postln;
```

### Expected vs Actual

**Expected:** `ABCNEWXYZ`

**Actual:** `ABCNEWZ` (the `XY` after the emoji is eaten)

### Why

`selectRange(3, 4)` correctly selects 4 UTF-16 code units (= 2 emoji).

But `selectedString_` calls `setTextInRange(text, 3, 4)` in the IDE, which uses:
```cpp
cursor.movePosition(QTextCursor::NextCharacter, QTextCursor::KeepAnchor, 4);
```

This moves 4 **characters** (codepoints), not 4 UTF-16 code units:
1. 🎹 (1 char)
2. 🎹 (1 char)
3. X (1 char)
4. Y (1 char)

So `🎹🎹XY` gets replaced instead of just `🎹🎹`.

## Workarounds

Until this is fixed in SuperCollider:

1. **Avoid non-BMP Unicode in editable regions** - Use only ASCII or BMP characters in content that will be programmatically replaced.

2. **Convert UTF-16 length to codepoint length** - Modify the sclang code to pass codepoint count instead of UTF-16 code unit count. This requires counting surrogate pairs and subtracting them from the range.

3. **Use file-based replacement** - Instead of using `Document.selectedString_`, write the modified content directly to the file and reload the document.

## Related Files in This Investigation

- `tests/m2/test-runner.scd` - Test harness with debugging
- `tests/m2/test-target.scd` - Test file with edge cases
- `tests/m09/wildcard-visual-m09-module.scd` - Byte↔UTF-16 converter
- `tests/m2/selectRange-experiment.scd` - Experiment confirming selectRange uses UTF-16

## References

- Qt Documentation: [QTextCursor::movePosition](https://doc.qt.io/qt-6/qtextcursor.html#movePosition) - Notes that NextCharacter moves by logical characters, not code units
- SuperCollider source: `editors/sc-ide/core/doc_manager.cpp`
- Unicode: Surrogate pairs in UTF-16 (U+10000 and above require 2 code units)
