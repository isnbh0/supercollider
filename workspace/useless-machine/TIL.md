# TIL - SuperCollider Insights

Lessons learned during wildcard-visual development.

---

## Document.open is synchronous

**Date:** 2026-01-12

**Problem:**
```supercollider
// WRONG - causes PrimitiveFailedError
Document.open(path, {|doc|
    doc.string.postln;
});
```

Error: `YAMLSerializer: not implementation for this type`

**Why:** The second argument is `selectionStart`, not a callback. The function gets serialized to send to the IDE, which fails.

**Solution:**
```supercollider
// CORRECT - synchronous call
var doc = Document.open(path);
doc.string.postln;
```

**Signature:**
```supercollider
Document.open(path, selectionStart: 0, selectionLength: 0, envir)
```

---

## SC module pattern: .load requires single expression

**Date:** 2026-01-12

**Problem:**
```supercollider
// my-module.scd - WRONG
(
~func1 = { ... };
)

(
~func2 = { ... };
)
```

```
ERROR: syntax error, unexpected '(', expecting end of file
```

**Why:** `.load` compiles the entire file as one expression. Multiple `()` blocks fail.

**Solution:** Split into two files:

### Module file (`*-module.scd`) - bare statements only

```supercollider
// my-module.scd
// NO parentheses blocks - just bare statements

~myFunc = {|x| x * 2 };

~anotherFunc = {|a, b| a + b };

"[Module] Functions loaded.".postln;
```

### Test/main file - loads module, then has blocks

```supercollider
// my-tests.scd

// ==================== LOAD MODULE ====================
(
var thisDir = PathName(thisProcess.nowExecutingPath).pathOnly;
var modulePath = thisDir +/+ "my-module.scd";
modulePath.load;
)

// ==================== TEST 1 ====================
(
var result = ~myFunc.(5);
if(result == 10, { "PASS".postln }, { "FAIL".postln });
)
```

### Quick reference

| Do | Don't |
|----|-------|
| Use bare statements in module files | Use `()` blocks in loadable modules |
| Load with `path.load` | Mix definitions and test blocks |
| Keep tests in separate file | Assume `.load` runs blocks independently |

### Loading pattern

```supercollider
var thisDir = PathName(thisProcess.nowExecutingPath).pathOnly;
var modulePath = thisDir +/+ "my-module.scd";
modulePath.load;

// Verify
if(~myFunc.notNil, { "Loaded.".postln }, { "FAIL".postln });
```

---

## String uses bytes, Document uses UTF-16

**Date:** 2026-01-11

**Problem:**
```supercollider
var pos = text.find("target");  // byte position
doc.selectRange(pos, 6);        // WRONG - selects wrong text
```

**Why:** SuperCollider uses two coordinate systems:
- `String` indexing = UTF-8 bytes
- `Document.selectRange` = UTF-16 code units (Qt internal)

Non-ASCII characters cause drift:

| Character | UTF-8 bytes | UTF-16 units | Drift |
|-----------|-------------|--------------|-------|
| ASCII | 1 | 1 | +0 |
| Latin ext, Greek | 2 | 1 | +1 |
| CJK, arrows, symbols | 3 | 1 | +2 |
| Emoji | 4 | 2 (surrogate) | +2 |

**Solution:** Convert positions before using selectRange:

```supercollider
var bytePos = text.find("target");
var utf16Pos = ~byteToUtf16.(text, bytePos);
doc.selectRange(utf16Pos, 6);  // CORRECT
```

Converter implementation in `wildcard-visual-m09-module.scd`.

---

## text.find() matches earliest occurrence

**Date:** 2026-01-12

**Problem:**
```supercollider
var text = doc.string;
var pos = text.find("~rev.(");  // Finds pattern in TEST CODE, not target!
```

When running tests, `text.find()` may match patterns in the test file itself before reaching the actual target.

**Solution:** Use a dedicated test target file, or use `File.readAllString` to read a specific file:

```supercollider
// Read specific file instead of Document.current
var text = File.readAllString(targetPath);
var pos = text.find("~rev.(");  // Only searches target file
```

---

## Re-fetch doc.string after modifications

**Date:** 2026-01-12

**Problem:**
```supercollider
var text = doc.string;
var pos1 = text.find("~jitter.(");

// Insert text earlier in document
doc.selectRange(100, 0);
doc.selectedString_("/* inserted */");

// pos1 is now WRONG - text shifted!
doc.selectRange(pos1, 10);  // Selects wrong location
```

**Why:** After any text modification, all subsequent byte positions shift by the length of inserted/deleted text.

**Solution:** Re-fetch `doc.string` and rescan positions after each modification:

```supercollider
// After modification:
text = doc.string;  // Re-fetch!
~visualRescanAll.();  // Rebuild position registry

// Now use fresh positions
var newPos = ~m1Registry[\jitter].byteStart;
```

**Rule:** One modification → one rescan. Don't batch multiple edits with stale positions.

---

## `var` declarations must be at the top of a block

**Date:** 2026-01-12

**Problem:**
```supercollider
if (condition) {
    "doing something".postln;
    var x = 5;  // ERROR!
};
```

```
ERROR: syntax error, unexpected VAR, expecting '}'
```

**Why:** SuperCollider requires all `var` declarations at the very beginning of a function or block, before any executable statements.

**Solution:**
```supercollider
if (condition) {
    var x;  // Declare first
    "doing something".postln;
    x = 5;  // Assign later
};
```

Or declare all vars at function top:
```supercollider
{ |arg1, arg2|
    var x, y, z;  // ALL vars here

    if (condition) {
        x = 5;
        // ...
    };
}
```

**Rule:** Vars go at the top. Always.
