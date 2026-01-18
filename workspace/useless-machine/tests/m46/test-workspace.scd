// ============================================================
// M4.6 TEST WORKSPACE - Async Mutation Observational Test
// ============================================================
// This file tests whether async background mutations visibly steal
// cursor focus or scroll the view.
//
// KEY DISCOVERY:
// - selectRange + selectedString_ DOES move cursor and scroll view
// - doc.string_(text, start, len) does NOT move cursor or scroll!
//   (It uses setTextInRange internally which creates a separate QTextCursor)
//
// INSTRUCTIONS:
// 1. Open this file in SC IDE
// 2. Run the SETUP block first (below the targets)
// 3. Place your cursor in the TEST BLOCK section (bottom)
// 4. Run the TEST BLOCK
// 5. OBSERVE: Does your cursor jump or view scroll when mutations fire?
//    - Cursor stays AND view doesn't scroll: PASS
//    - Cursor jumps OR view scrolls: FAIL
// ============================================================

// ============================================================
// MUTATION TARGETS (top section - mutations happen here)
// ============================================================

~alpha.(MUT1);

~beta.(MUTATION2);

~gamma.(M3);

~delta.(MUTATED_4);

// ============================================================
// PADDING (middle section)
// ============================================================
// This padding creates distance between mutation targets and test code.
// The user's cursor will be in the test block below.
// If async mutations work correctly, the cursor should NOT jump up here.
//
// Line 1 of padding
// Line 2 of padding
// Line 3 of padding
// Line 4 of padding
// Line 5 of padding
// Line 6 of padding
// Line 7 of padding
// Line 8 of padding
// Line 9 of padding
// Line 10 of padding
//
// ============================================================

// ============================================================
// SETUP: Load utilities (run this FIRST)
// ============================================================

(
// === UTF-8/UTF-16 CONVERTERS (from M09) ===

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

~utf16UnitCount = { |utf8ByteLen|
    if(utf8ByteLen == 4, { 2 }, { 1 });
};

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

// === NO-CURSOR-MOVE REPLACEMENT ===
// Uses doc.string_ which internally calls setTextInRange (separate QTextCursor)
// This does NOT move cursor or scroll the view!

~m46ReplaceNoCursorMove = { |doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd;
    var utf16Start, utf16Len;
    var depth;

    // Find the pattern
    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4.6] Controller '%' not found".format(controllerName).postln;
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

        utf16Start = ~byteToUtf16.(text, contentStart);
        utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

        // Use doc.string_ which doesn't move cursor or scroll!
        doc.string_(newValue, utf16Start, utf16Len);

        true;
    };
};

// === MUTATION HELPER ===

~m46Mutate = { |doc, controllerName, newValue|
    ~m46ReplaceNoCursorMove.(doc, controllerName, newValue);
};

"[M4.6] Setup complete - utilities loaded".postln;
"[M4.6] Now place cursor in TEST BLOCK and run it".postln;
)

// ============================================================
// TEST BLOCK (run with cursor HERE)
// ============================================================
// Place your cursor somewhere in this block before running.
// Watch if your cursor jumps when mutations fire above.
// ============================================================

(
"".postln;
"============================================================".postln;
"[M4.6] ASYNC MUTATION OBSERVATIONAL TEST".postln;
"============================================================".postln;
"[M4.6] Keep your cursor HERE and watch for jumps!".postln;
"[M4.6] Mutations will fire at 1s, 2s, 3s, 4s intervals...".postln;
"============================================================".postln;
"".postln;

{
    var doc = Document.current;
    var controllers = [\alpha, \beta, \gamma, \delta];
    var mutations = ["MUT1", "MUTATION2", "M3", "MUTATED_4"];

    4.do { |i|
        (i + 1).wait;
        "[M4.6] >>> Mutation % firing NOW <<<".format(i + 1).postln;
        ~m46Mutate.(doc, controllers[i], mutations[i]);
        "[M4.6] Mutation % complete".format(i + 1).postln;
    };

    "".postln;
    "============================================================".postln;
    "[M4.6] All mutations complete.".postln;
    "[M4.6] Did your cursor stay in this block?".postln;
    "[M4.6]   YES -> PASS (cursor preservation works)".postln;
    "[M4.6]   NO  -> FAIL (cursor jumped to mutation site)".postln;
    "============================================================".postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.6a: Single async mutation
// ============================================================
// Simpler test: just one mutation after 2 seconds

(
"[TEST 4.6a] Single async mutation".postln;
"[TEST 4.6a] Mutation fires in 2 seconds...".postln;
{
    var doc = Document.current;
    2.wait;
    "[TEST 4.6a] >>> Mutating ~alpha NOW <<<".postln;
    ~m46Mutate.(doc, "alpha", "SINGLE_TEST");
    "[TEST 4.6a] Did your cursor jump? YES=FAIL, NO=PASS".postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.6b: Rapid mutations (stress test)
// ============================================================
// 10 mutations in quick succession (0.3s apart)

(
"[TEST 4.6b] Rapid mutation stress test".postln;
"[TEST 4.6b] 10 mutations, 0.3s apart...".postln;
{
    var doc = Document.current;
    var targets = [\alpha, \beta, \gamma, \delta];

    10.do { |i|
        0.3.wait;
        var target = targets.wrapAt(i);
        var value = String.fill(i + 1, $.);
        "[TEST 4.6b] Mutation % -> %".format(i + 1, target).postln;
        ~m46Mutate.(doc, target, value);
    };

    "[TEST 4.6b] Complete. Did cursor jump at any point?".postln;
}.fork(AppClock);
)

// ============================================================
// RESET: Restore original values
// ============================================================

(
"[RESET] Restoring original controller values...".postln;
{
    var doc = Document.current;
    ~m46Mutate.(doc, "alpha", ".........");
    ~m46Mutate.(doc, "beta", "......");
    ~m46Mutate.(doc, "gamma", "....");
    ~m46Mutate.(doc, "delta", "........");
    "[RESET] Done".postln;
}.fork(AppClock);
)

// ============================================================
// END OF FILE
// ============================================================
