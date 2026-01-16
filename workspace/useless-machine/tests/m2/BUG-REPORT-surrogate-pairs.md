# Bug Report: Surrogate Pair Replacement Eats Closing `);`

**Status:** FIXED in commit `86238d725`

## Summary

When replacing content that contains non-BMP Unicode characters (emoji, musical symbols), the replacement eats the closing `);` of the controller pattern.

## Reproduction

1. Clean file has: `~emoji.(🎹🎹);`
2. Run replacement to change content to `0.3`
3. Result: `~emoji.(0.3` ← missing `);`

## Affected Cases

- Emoji: 🎹 (U+1F3B9) - 4-byte UTF-8, 2 UTF-16 code units (surrogate pair)
- Musical symbols: 𝄞 (U+1D11E) - 4-byte UTF-8, 2 UTF-16 code units
- Any non-BMP character (codepoint > U+FFFF)

## Working Cases

- ASCII content
- BMP Unicode (arrows →, CJK 한글) - 3-byte UTF-8, 1 UTF-16 code unit

## Key Files

- `tests/m2/test-runner.scd` - Test harness with `~replaceController` helper
- `tests/m2/test-target.scd` - Test file with controller patterns
- `tests/m09/wildcard-visual-m09-module.scd` - UTF-8 ↔ UTF-16 converter functions

## Relevant Code

The replacement logic in `~replaceController`:

```supercollider
// Find content bounds (byte positions)
contentStart = patternPos + pattern.size;
contentEnd = /* paren depth counter finds ) */;

// Convert to UTF-16 for Document API
utf16Start = ~byteToUtf16.(text, contentStart);
utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

// Replace
doc.selectRange(utf16Start, utf16Len);
doc.selectedString_(newValue);
```

## Debug Output (from failing test)

```
[REPLACE] emoji: bytes 703..711 (len 8)      ← byte positions CORRECT
[REPLACE] emoji: utf16 703..+4               ← utf16 length looks correct (2 emoji × 2 units)
[DEBUG] After replace, doc shows: '~emoji.(0.3'  ← BUT result is corrupted!
[DEBUG] Looking for: '~emoji.(0.3);'
[DEBUG] find() returned: nil
[REPLACE] emoji VERIFICATION FAILED!
```

## Hypothesis

The byte→UTF-16 position conversion is correct in isolation (M0.9 tests pass), but something goes wrong when `selectRange` uses these positions. Possible issues:

1. Off-by-one in UTF-16 length calculation for surrogate pairs
2. `selectRange` interprets the length differently than expected
3. Accumulated drift calculation error when surrogate pairs are in the content being replaced

## Converter Functions (for reference)

```supercollider
~utf8ByteLength = {|leadingByte| /* returns 1/2/3/4 based on UTF-8 lead byte */ };
~utf16UnitCount = {|utf8ByteLen| if(utf8ByteLen == 4, { 2 }, { 1 }) };
~byteToUtf16 = {|text, bytePos| /* walks text, converts byte pos to UTF-16 pos */ };
```

## Resolution

**Root cause:** SC IDE's `Document.setTextInRange` in `editors/sc-ide/core/doc_manager.cpp` used inconsistent position semantics:
- `setPosition()` uses UTF-16 code units
- `movePosition(NextCharacter)` moves by graphemes (user-perceived characters)

For emoji like 🎹 (1 grapheme = 2 UTF-16 code units), passing `range=4` (for 2 emoji × 2 UTF-16 units) to `movePosition` moved 4 graphemes instead of 4 code units, selecting too much text.

**Fix:**
```cpp
// Before (broken)
cursor.movePosition(QTextCursor::NextCharacter, QTextCursor::KeepAnchor, range);

// After (fixed)
cursor.setPosition(start + range, QTextCursor::KeepAnchor);
```

**Requires:** SC IDE built from branch `projects/useless-machine` or with equivalent patch applied.
