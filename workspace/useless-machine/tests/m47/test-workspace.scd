// ============================================================
// M4.7 TEST WORKSPACE - Async Mutation + Code Execution Test
// ============================================================
// This file tests whether async background mutations + code execution
// steal cursor focus or scroll the view.
//
// EXTENDS M4.6:
// - M4.6 proved doc.string_ does stealth edits (no cursor/scroll steal)
// - M4.7 adds code execution via .interpret after mutation
//
// KEY QUESTIONS:
// 1. Does "code".interpret steal focus?
// 2. Does executing code that references Document.current cause issues?
// 3. Can we mutate + execute without any visible disruption?
//
// INSTRUCTIONS:
// 1. Open this file in SC IDE
// 2. Run the SETUP block first (loads utilities and defines controllers)
// 3. Place your cursor in the TEST BLOCK section (bottom)
// 4. Run the TEST BLOCK
// 5. OBSERVE:
//    - Cursor stays AND view doesn't scroll: PASS
//    - Cursor jumps OR view scrolls: FAIL
//    - Check post window for execution confirmation
// ============================================================

// ============================================================
// MUTATION TARGETS (top section - mutations happen here)
// ============================================================
// These controllers actually DO something when executed.
// They set environment variables so we can verify execution.

~alpha.(".........");

~beta.("......");

~gamma.("....");

~delta.("........");

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
// Line 11 of padding
// Line 12 of padding
// Line 13 of padding
// Line 14 of padding
// Line 15 of padding
// Line 16 of padding
// Line 17 of padding
// Line 18 of padding
// Line 19 of padding
// Line 20 of padding
//
// ============================================================

// ============================================================
// SETUP: Load utilities + define controllers (run this FIRST)
// ============================================================

(
// === CONTROLLER DEFINITIONS ===
// These functions actually DO something when called.
// They set environment variables and post to console,
// so we can verify the code actually executed.

~alpha = { |dots|
    ~alphaValue = dots;
    ~alphaCount = (~alphaCount ? 0) + 1;
    "[EXEC] ~alpha executed with '%' (count: %)".format(dots, ~alphaCount).postln;
};

~beta = { |dots|
    ~betaValue = dots;
    ~betaCount = (~betaCount ? 0) + 1;
    "[EXEC] ~beta executed with '%' (count: %)".format(dots, ~betaCount).postln;
};

~gamma = { |dots|
    ~gammaValue = dots;
    ~gammaCount = (~gammaCount ? 0) + 1;
    "[EXEC] ~gamma executed with '%' (count: %)".format(dots, ~gammaCount).postln;
};

~delta = { |dots|
    ~deltaValue = dots;
    ~deltaCount = (~deltaCount ? 0) + 1;
    "[EXEC] ~delta executed with '%' (count: %)".format(dots, ~deltaCount).postln;
};

// Reset execution counters
~alphaCount = 0;
~betaCount = 0;
~gammaCount = 0;
~deltaCount = 0;

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

// === NO-CURSOR-MOVE REPLACEMENT (from M4.6) ===
// Uses doc.string_ which internally calls setTextInRange (separate QTextCursor)
// This does NOT move cursor or scroll the view!

~m47ReplaceNoCursorMove = { |doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd;
    var utf16Start, utf16Len;
    var depth;

    // Find the pattern
    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4.7] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        contentStart = patternPos + pattern.size;

        // Find the content by looking for closing quote
        // Pattern: ~name.("content")
        // We need to find the content between quotes
        if (text[contentStart] == $") {
            // Content is a quoted string
            contentStart = contentStart + 1;  // skip opening quote
            contentEnd = text.find("\"", false, contentStart);
            if (contentEnd.isNil) {
                "[M4.7] Could not find closing quote for '%'".format(controllerName).postln;
                false;
            } {
                utf16Start = ~byteToUtf16.(text, contentStart);
                utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

                // Use doc.string_ which doesn't move cursor or scroll!
                doc.string_(newValue, utf16Start, utf16Len);
                true;
            };
        } {
            "[M4.7] Expected quoted string for '%'".format(controllerName).postln;
            false;
        };
    };
};

// === MUTATION + EXECUTE HELPER ===
// This is the key M4.7 function: mutate document AND execute the code

~m47MutateAndExecute = { |doc, controllerName, newValue|
    var success, code;

    // Step 1: Stealth edit the document
    success = ~m47ReplaceNoCursorMove.(doc, controllerName, newValue);

    if (success) {
        // Step 2: Build and execute the code
        code = "~" ++ controllerName ++ ".(\"" ++ newValue ++ "\")";
        "[M4.7] Interpreting: %".format(code).postln;
        code.interpret;
    };

    success;
};

"".postln;
"[M4.7] Setup complete - utilities and controllers loaded".postln;
"[M4.7] Controllers defined: ~alpha, ~beta, ~gamma, ~delta".postln;
"[M4.7] Now place cursor in TEST BLOCK and run it".postln;
"".postln;
)

// ============================================================
// TEST BLOCK (run with cursor HERE)
// ============================================================
// Place your cursor somewhere in this block before running.
// Watch if your cursor jumps when mutations fire above.
// Check post window for "[EXEC]" messages confirming code ran.
// ============================================================

(
"".postln;
"============================================================".postln;
"[M4.7] ASYNC MUTATION + CODE EXECUTION TEST".postln;
"============================================================".postln;
"[M4.7] Keep your cursor HERE and watch for jumps!".postln;
"[M4.7] Mutations will fire at 1s, 2s, 3s, 4s intervals...".postln;
"[M4.7] Watch for '[EXEC]' messages confirming code ran.".postln;
"============================================================".postln;
"".postln;

{
    var doc = Document.current;
    var controllers = [\alpha, \beta, \gamma, \delta];
    var mutations = ["...", ".....", ".", "......."];

    4.do { |i|
        (i + 1).wait;
        "[M4.7] >>> Mutation % firing NOW <<<".format(i + 1).postln;
        ~m47MutateAndExecute.(doc, controllers[i], mutations[i]);
        "[M4.7] Mutation % complete".format(i + 1).postln;
    };

    "".postln;
    "============================================================".postln;
    "[M4.7] All mutations complete.".postln;
    "============================================================".postln;
    "[M4.7] CURSOR CHECK:".postln;
    "[M4.7]   Cursor stayed in this block? YES=PASS, NO=FAIL".postln;
    "============================================================".postln;
    "[M4.7] EXECUTION CHECK:".postln;
    "[M4.7]   ~alphaCount = % (expected: 1)".format(~alphaCount).postln;
    "[M4.7]   ~betaCount = % (expected: 1)".format(~betaCount).postln;
    "[M4.7]   ~gammaCount = % (expected: 1)".format(~gammaCount).postln;
    "[M4.7]   ~deltaCount = % (expected: 1)".format(~deltaCount).postln;
    "[M4.7]   All counts = 1? YES=CODE_EXECUTED, NO=CODE_FAILED".postln;
    "============================================================".postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.7a: Single async mutation + execute
// ============================================================
// Simpler test: just one mutation + execute after 2 seconds

(
"[TEST 4.7a] Single async mutation + execute".postln;
"[TEST 4.7a] Mutation fires in 2 seconds...".postln;
~alphaCount = 0;  // Reset counter
{
    var doc = Document.current;
    2.wait;
    "[TEST 4.7a] >>> Mutating + executing ~alpha NOW <<<".postln;
    ~m47MutateAndExecute.(doc, "alpha", "TEST_SINGLE");
    "[TEST 4.7a] Did your cursor jump? YES=FAIL, NO=PASS".postln;
    "[TEST 4.7a] ~alphaCount = % (should be 1)".format(~alphaCount).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.7b: Rapid mutations + execute (stress test)
// ============================================================
// 10 mutations + executions in quick succession (0.3s apart)

(
"[TEST 4.7b] Rapid mutation + execute stress test".postln;
"[TEST 4.7b] 10 mutations, 0.3s apart...".postln;
// Reset counters
~alphaCount = 0;
~betaCount = 0;
~gammaCount = 0;
~deltaCount = 0;
{
    var doc = Document.current;
    var targets = [\alpha, \beta, \gamma, \delta];

    10.do { |i|
        0.3.wait;
        var target = targets.wrapAt(i);
        var value = String.fill(i + 1, $.);
        "[TEST 4.7b] Mutation % -> %".format(i + 1, target).postln;
        ~m47MutateAndExecute.(doc, target, value);
    };

    "[TEST 4.7b] Complete. Did cursor jump at any point?".postln;
    "[TEST 4.7b] Execution counts:".postln;
    "[TEST 4.7b]   ~alphaCount = %".format(~alphaCount).postln;
    "[TEST 4.7b]   ~betaCount = %".format(~betaCount).postln;
    "[TEST 4.7b]   ~gammaCount = %".format(~gammaCount).postln;
    "[TEST 4.7b]   ~deltaCount = %".format(~deltaCount).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 4.7c: Verify code with side effects
// ============================================================
// This test uses a controller that has an observable side effect
// beyond just setting a variable

(
// Define a controller that posts a distinctive message
~testSideEffect = { |dots|
    var len = dots.size;
    "".postln;
    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!".postln;
    "!!! SIDE EFFECT OBSERVED: % dots !!!".format(len).postln;
    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!".postln;
    "".postln;
    ~sideEffectValue = len;
};

"[TEST 4.7c] Side effect test".postln;
"[TEST 4.7c] Watch for '!!! SIDE EFFECT OBSERVED !!!' messages".postln;
~sideEffectValue = nil;
{
    var doc = Document.current;
    // Note: This test requires manually adding ~testSideEffect.("...") to targets section
    // Or we test with existing controllers
    3.do { |i|
        (i + 1).wait;
        var dots = String.fill((i + 1) * 3, $.);
        "[TEST 4.7c] Mutation % with % dots".format(i + 1, dots.size).postln;
        ~m47MutateAndExecute.(doc, "alpha", dots);
    };
    "[TEST 4.7c] Complete. Check for side effect messages above.".postln;
}.fork(AppClock);
)

// ============================================================
// RESET: Restore original values
// ============================================================

(
"[RESET] Restoring original controller values...".postln;
{
    var doc = Document.current;
    ~m47MutateAndExecute.(doc, "alpha", ".........");
    ~m47MutateAndExecute.(doc, "beta", "......");
    ~m47MutateAndExecute.(doc, "gamma", "....");
    ~m47MutateAndExecute.(doc, "delta", "........");
    "[RESET] Done".postln;
}.fork(AppClock);
)

// ============================================================
// VERIFICATION: Check execution state
// ============================================================

(
"".postln;
"============================================================".postln;
"[VERIFY] Current execution state:".postln;
"============================================================".postln;
"[VERIFY] ~alphaValue = '%'".format(~alphaValue).postln;
"[VERIFY] ~betaValue = '%'".format(~betaValue).postln;
"[VERIFY] ~gammaValue = '%'".format(~gammaValue).postln;
"[VERIFY] ~deltaValue = '%'".format(~deltaValue).postln;
"[VERIFY] ~alphaCount = %".format(~alphaCount).postln;
"[VERIFY] ~betaCount = %".format(~betaCount).postln;
"[VERIFY] ~gammaCount = %".format(~gammaCount).postln;
"[VERIFY] ~deltaCount = %".format(~deltaCount).postln;
"============================================================".postln;
)

// ============================================================
// END OF FILE
// ============================================================
