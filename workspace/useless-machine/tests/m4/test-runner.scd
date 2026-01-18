// ============================================================
// M4 TEST RUNNER - Repeated Operations with Breadcrumbs
// ============================================================
// Tests multiple mutations with breadcrumb insertion.
// Standalone - does not depend on M2/M3 tests.
// ============================================================

// ============================================================
// SETUP: Converter functions (from M09 with signed byte handling)
// ============================================================

(
// UTF-8 byte length from leading byte (handles signed byte values)
~utf8ByteLength = {|leadingByte|
    var code = leadingByte.ascii;
    case
        { code < 0 } {
            var unsigned = code + 256;
            case
                { unsigned < 194 } { 1 }
                { unsigned < 224 } { 2 }
                { unsigned < 240 } { 3 }
                { unsigned < 248 } { 4 }
                { 1 };
        }
        { code < 128 } { 1 }
        { 1 };
};

// UTF-16 units for a UTF-8 sequence (4-byte = surrogate pair = 2 units)
~utf16UnitCount = { |utf8ByteLen|
    if(utf8ByteLen == 4, { 2 }, { 1 });
};

// Convert byte position to UTF-16 position
~byteToUtf16 = { |text, bytePos|
    var utf16Pos = 0;
    var i = 0;
    var textSize = text.size;
    while { (i < bytePos) and: { i < textSize } } {
        var byteLen = ~utf8ByteLength.(text[i]);
        utf16Pos = utf16Pos + ~utf16UnitCount.(byteLen);
        i = i + byteLen;
    };
    utf16Pos;
};

"[M4] Converter functions loaded".postln;
)

// ============================================================
// SETUP: Get target document handle (without stealing focus)
// ============================================================

(
var m4Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var targetFilename = "test-target.scd";

~m4Dir = m4Dir;
~m4TargetPath = m4Dir +/+ targetFilename;

// Try to find already-open document first (no focus steal)
~m4Doc = Document.allDocuments.detect { |doc| doc.title == targetFilename };

if (~m4Doc.isNil) {
    // Not open yet - must use Document.open (will steal focus)
    var currentDoc = Document.current;
    ~m4Doc = Document.open(~m4TargetPath);
    // Return focus to original
    currentDoc.front;
    "[M4] Opened target (returned focus)".postln;
} {
    "[M4] Found target in allDocuments (no focus change)".postln;
};

"[M4] Setup complete. Target: %".format(~m4TargetPath).postln;
)

// ============================================================
// HELPER: Replace controller content (standalone version)
// ============================================================

(
~m4Replace = { |doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth;
    var utf16Start, utf16Len;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4-REPLACE] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        contentStart = patternPos + pattern.size;

        // Find matching close paren
        contentEnd = contentStart;
        depth = 1;
        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };

        // Convert to UTF-16
        utf16Start = ~byteToUtf16.(text, contentStart);
        utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

        // Replace
        doc.selectRange(utf16Start, utf16Len);
        doc.selectedString_(newValue);

        "[M4-REPLACE] % -> '%'".format(controllerName, newValue).postln;
        true;
    };
};

"[M4] Helper ~m4Replace defined".postln;
)

// ============================================================
// HELPER: Insert breadcrumb before controller
// ============================================================

(
~m4Breadcrumb = { |doc, controllerName, mutationNum|
    var text, pattern, patternPos, lineStart, utf16Start;
    var breadcrumb;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4-BREADCRUMB] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        // Find line start (search backwards for newline)
        lineStart = text[0..patternPos].findBackwards("\n");
        lineStart = if(lineStart.isNil, { 0 }, { lineStart + 1 });

        // Create breadcrumb
        breadcrumb = "// ======= WILDCARD #% ======= % =======\n".format(
            mutationNum, controllerName.asString.toUpper
        );

        // Insert at line start
        utf16Start = ~byteToUtf16.(text, lineStart);
        doc.selectRange(utf16Start, 0);
        doc.selectedString_(breadcrumb);

        "[M4-BREADCRUMB] Inserted before %".format(controllerName).postln;
        true;
    };
};

"[M4] Helper ~m4Breadcrumb defined".postln;
)

// ============================================================
// HELPER: Verify controller has expected value
// ============================================================

(
~m4Verify = { |doc, controllerName, expectedValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth, actual;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4-VERIFY] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        contentStart = patternPos + pattern.size;
        contentEnd = contentStart;
        depth = 1;
        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };

        actual = text[contentStart..(contentEnd - 1)];
        if (actual == expectedValue) {
            "[M4-VERIFY] % == '%' OK".format(controllerName, expectedValue).postln;
            true;
        } {
            "[M4-VERIFY] % MISMATCH: expected '%', got '%'".format(
                controllerName, expectedValue, actual
            ).postln;
            false;
        };
    };
};

"[M4] Helper ~m4Verify defined".postln;
)

// ============================================================
// TEST 4.1: 5 sequential replacements (no breadcrumbs)
// ============================================================

(
"[TEST 4.1] 5 sequential replacements".postln;
{
    var controllers = [\alpha, \beta, \gamma, \alpha, \beta];
    var values = ["AAA", "BBB", "CCC", "DDD", "EEE"];
    var results = [];

    controllers.do { |name, i|
        var ok;
        0.1.wait;
        ok = ~m4Replace.(~m4Doc, name, values[i]);
        results = results.add(ok);
    };

    0.2.wait;

    // Verify final state
    results = results.add(~m4Verify.(~m4Doc, "alpha", "DDD"));
    results = results.add(~m4Verify.(~m4Doc, "beta", "EEE"));
    results = results.add(~m4Verify.(~m4Doc, "gamma", "CCC"));

    "[TEST 4.1] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.2: Single breadcrumb + replacement
// ============================================================

(
"[TEST 4.2] Single breadcrumb + replacement".postln;
{
    var ok1, ok2, ok3;
    0.2.wait;

    // Insert breadcrumb
    ok1 = ~m4Breadcrumb.(~m4Doc, "gamma", 1);
    0.1.wait;

    // Replace (positions shifted!)
    ok2 = ~m4Replace.(~m4Doc, "gamma", "BREAD1");
    0.1.wait;

    // Verify
    ok3 = ~m4Verify.(~m4Doc, "gamma", "BREAD1");

    "[TEST 4.2] breadcrumb:%, replace:%, verify:% -> %".format(
        ok1, ok2, ok3, if(ok1 && ok2 && ok3, "PASS", "FAIL")
    ).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.3: 3 breadcrumb+replacement cycles
// ============================================================

(
"[TEST 4.3] 3 breadcrumb+replacement cycles".postln;
{
    var controllers = [\alpha, \beta, \gamma];
    var values = ["CYCLE1", "CYCLE2", "CYCLE3"];
    var results = [];

    controllers.do { |name, i|
        var okB, okR;
        0.1.wait;

        // Breadcrumb
        okB = ~m4Breadcrumb.(~m4Doc, name, i + 10);
        0.1.wait;

        // Replace
        okR = ~m4Replace.(~m4Doc, name, values[i]);
        results = results.add(okB && okR);
    };

    0.2.wait;

    // Verify all
    results = results.add(~m4Verify.(~m4Doc, "alpha", "CYCLE1"));
    results = results.add(~m4Verify.(~m4Doc, "beta", "CYCLE2"));
    results = results.add(~m4Verify.(~m4Doc, "gamma", "CYCLE3"));

    "[TEST 4.3] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.4: Verify END_MARKER intact after all operations
// ============================================================

(
"[TEST 4.4] END_MARKER integrity".postln;
{
    var text, ok;
    0.2.wait;
    text = ~m4Doc.string;
    ok = text.find("END_MARKER: OK").notNil;
    "[TEST 4.4] %".format(if(ok, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// ADVERSARIAL TESTS
// ============================================================

// ============================================================
// TEST 4.5: Reverse order operations (bottom-to-top)
// ============================================================
// Risk: Position caching without invalidation

(
"[TEST 4.5] Reverse order (bottom-to-top)".postln;
{
    var controllers = [\gamma, \beta, \alpha];  // reverse order
    var values = ["REV3", "REV2", "REV1"];
    var results = [];

    controllers.do { |name, i|
        var okB, okR;
        0.1.wait;
        okB = ~m4Breadcrumb.(~m4Doc, name, 50 + i);
        0.1.wait;
        okR = ~m4Replace.(~m4Doc, name, values[i]);
        results = results.add(okB && okR);
    };

    0.2.wait;
    results = results.add(~m4Verify.(~m4Doc, "gamma", "REV3"));
    results = results.add(~m4Verify.(~m4Doc, "beta", "REV2"));
    results = results.add(~m4Verify.(~m4Doc, "alpha", "REV1"));

    "[TEST 4.5] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.6: Adjacent controllers (no gap between lines)
// ============================================================
// Risk: Breadcrumb before adj1 shifts adj2 on very next line

(
"[TEST 4.6] Adjacent controllers".postln;
{
    var results = [];
    0.2.wait;

    // Breadcrumb + replace adj1
    results = results.add(~m4Breadcrumb.(~m4Doc, "adj1", 60));
    0.1.wait;
    results = results.add(~m4Replace.(~m4Doc, "adj1", "ADJ1_OK"));
    0.1.wait;

    // Breadcrumb + replace adj2 (immediately after adj1)
    results = results.add(~m4Breadcrumb.(~m4Doc, "adj2", 61));
    0.1.wait;
    results = results.add(~m4Replace.(~m4Doc, "adj2", "ADJ2_OK"));
    0.1.wait;

    // Verify both
    results = results.add(~m4Verify.(~m4Doc, "adj1", "ADJ1_OK"));
    results = results.add(~m4Verify.(~m4Doc, "adj2", "ADJ2_OK"));

    "[TEST 4.6] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.7: Unicode breadcrumb content
// ============================================================
// Risk: UTF-8/UTF-16 drift in breadcrumb text itself

(
// Custom breadcrumb helper with unicode content
~m4UnicodeBreadcrumb = { |doc, controllerName, mutationNum|
    var text, pattern, patternPos, lineStart, utf16Start;
    var breadcrumb;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        false;
    } {
        lineStart = text[0..patternPos].findBackwards("\n");
        lineStart = if(lineStart.isNil, { 0 }, { lineStart + 1 });

        // Unicode breadcrumb: emoji + CJK + arrows
        breadcrumb = "// 🎲 WILDCARD #% → % (시간: now) 🎵\n".format(
            mutationNum, controllerName.asString.toUpper
        );

        utf16Start = ~byteToUtf16.(text, lineStart);
        doc.selectRange(utf16Start, 0);
        doc.selectedString_(breadcrumb);
        true;
    };
};

"[M4] Unicode breadcrumb helper defined".postln;
)

(
"[TEST 4.7] Unicode breadcrumb content".postln;
{
    var results = [];
    0.2.wait;

    // Insert unicode breadcrumbs before each controller
    [\alpha, \beta, \gamma].do { |name, i|
        var okB, okR;
        0.1.wait;
        okB = ~m4UnicodeBreadcrumb.(~m4Doc, name, 70 + i);
        0.1.wait;
        okR = ~m4Replace.(~m4Doc, name, "UNI" ++ (i+1));
        results = results.add(okB && okR);
    };

    0.2.wait;
    results = results.add(~m4Verify.(~m4Doc, "alpha", "UNI1"));
    results = results.add(~m4Verify.(~m4Doc, "beta", "UNI2"));
    results = results.add(~m4Verify.(~m4Doc, "gamma", "UNI3"));

    "[TEST 4.7] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.8: First-line controller (position 0 boundary)
// ============================================================
// Risk: Off-by-one at document start, findBackwards("\n") returns nil

(
"[TEST 4.8] First-line controller".postln;
{
    var results = [];
    0.2.wait;

    // firstLine is at byte 0 - boundary case
    results = results.add(~m4Breadcrumb.(~m4Doc, "firstLine", 80));
    0.1.wait;
    results = results.add(~m4Replace.(~m4Doc, "firstLine", "FIRST_OK"));
    0.1.wait;
    results = results.add(~m4Verify.(~m4Doc, "firstLine", "FIRST_OK"));

    "[TEST 4.8] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.9: Stress test - 10 operations with accumulating drift
// ============================================================
// Risk: Small errors compound over many operations

(
"[TEST 4.9] Stress test (10 breadcrumb+replace cycles)".postln;
{
    var controllers = [\s01, \s02, \s03, \s04, \s05, \s06, \s07, \s08, \s09, \s10];
    var results = [];

    controllers.do { |name, i|
        var okB, okR;
        0.05.wait;
        okB = ~m4Breadcrumb.(~m4Doc, name, 90 + i);
        0.05.wait;
        okR = ~m4Replace.(~m4Doc, name, "S" ++ (i+1).asString.padLeft(2, "0"));
        results = results.add(okB && okR);
        "[TEST 4.9] Op %/10: %".format(i+1, if(okB && okR, "OK", "FAIL")).postln;
    };

    0.2.wait;

    // Verify first, middle, and last
    results = results.add(~m4Verify.(~m4Doc, "s01", "S01"));
    results = results.add(~m4Verify.(~m4Doc, "s05", "S05"));
    results = results.add(~m4Verify.(~m4Doc, "s10", "S10"));

    // END_MARKER still intact?
    results = results.add(~m4Doc.string.find("END_MARKER: OK").notNil);

    "[TEST 4.9] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.10: Empty/minimal breadcrumb
// ============================================================
// Risk: Zero-length or minimal shifts might be special-cased incorrectly

(
~m4MinimalBreadcrumb = { |doc, controllerName|
    var text, pattern, patternPos, lineStart, utf16Start;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        false;
    } {
        lineStart = text[0..patternPos].findBackwards("\n");
        lineStart = if(lineStart.isNil, { 0 }, { lineStart + 1 });

        // Minimal breadcrumb - just 3 bytes
        utf16Start = ~byteToUtf16.(text, lineStart);
        doc.selectRange(utf16Start, 0);
        doc.selectedString_("//\n");
        true;
    };
};

"[M4] Minimal breadcrumb helper defined".postln;
)

(
"[TEST 4.10] Minimal breadcrumb (3 bytes)".postln;
{
    var results = [];
    0.2.wait;

    results = results.add(~m4MinimalBreadcrumb.(~m4Doc, "final"));
    0.1.wait;
    results = results.add(~m4Replace.(~m4Doc, "final", "MIN_OK"));
    0.1.wait;
    results = results.add(~m4Verify.(~m4Doc, "final", "MIN_OK"));

    "[TEST 4.10] % -> %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// VERIFY: Print current state
// ============================================================

(
"[VERIFY] Current target:".postln;
{ 0.2.wait; ~m4Doc.string.postln; }.fork(AppClock);
)

// ============================================================
// RESET: Restore original
// ============================================================

(
"[RESET] Restoring...".postln;
{
    var original = "~firstLine.(...);
// ============================================================
// M4 TEST TARGET - Repeated Operations with Breadcrumbs
// ============================================================
// Standalone fixture for M4 tests.
// ============================================================

// === CONTROLLERS ===
~alpha.(.......);
~beta.(....);
~gamma.(..........);

// === ADJACENT CONTROLLERS (no blank line between) ===
~adj1.(AAA);
~adj2.(BBB);

// === STRESS TEST CONTROLLERS ===
~s01.(.); ~s02.(.); ~s03.(.); ~s04.(.); ~s05.(.);
~s06.(.); ~s07.(.); ~s08.(.); ~s09.(.); ~s10.(.);

// === AFTER CONTROLLERS ===
~final.(.....);

// END_MARKER: OK";
    var text, utf16Len;
    0.2.wait;
    text = ~m4Doc.string;
    utf16Len = ~byteToUtf16.(text, text.size);
    ~m4Doc.selectRange(0, utf16Len);
    ~m4Doc.selectedString_(original);
    "[RESET] Done".postln;
}.fork(AppClock);
)
