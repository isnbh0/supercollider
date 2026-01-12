// ============================================================
// M2/M3 TEST RUNNER - Single & Multiple Text Replacement
// ============================================================
// Tests replacing placeholder strings with actual values.
// Includes edge cases: unicode, multiline, empty, etc.
// ============================================================

// ============================================================
// SETUP: Load dependencies and open target
// ============================================================

(
var m2Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Dir = m2Dir +/+ "../m09/";

// Load converter
(m09Dir +/+ "wildcard-visual-m09-module.scd").load;

// Store paths globally for tests
~m2Dir = m2Dir;
~targetPath = m2Dir +/+ "test-target.scd";

// Open target document (do this once)
~targetDoc = Document.open(~targetPath);

"[M2/M3] Setup complete. Target: %".format(~targetPath).postln;
)

// ============================================================
// HELPER: Replace content between ~name.( and );
// ============================================================
// More robust than just finding dots - finds closing paren.

(
~replaceController = { |doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth;
    var utf16Start, utf16Len;
    var verified, verifyText, expectedPattern, snippet;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[REPLACE] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        contentStart = patternPos + pattern.size;

        // Find matching close paren (handle nested parens)
        contentEnd = contentStart;
        depth = 1;
        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };

        "[REPLACE] %: bytes %..% (len %)".format(
            controllerName, contentStart, contentEnd, contentEnd - contentStart
        ).postln;

        // Convert to UTF-16
        utf16Start = ~byteToUtf16.(text, contentStart);
        utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

        "[REPLACE] %: utf16 %..+%".format(controllerName, utf16Start, utf16Len).postln;

        // Replace
        doc.selectRange(utf16Start, utf16Len);

        // DEBUG: What did selectRange actually select?
        "[DEBUG] selectRange selected: '%' (% bytes)".format(
            doc.selectedString, doc.selectedString.size
        ).postln;

        // Store selection info before replacement
        "[DEBUG] selectionStart: %, selectionSize: %".format(
            doc.selectionStart, doc.selectionSize
        ).postln;

        // BEFORE replacement: capture byte-level state
        {
            var beforeContent = doc.string;
            var beforeEmojiPos = beforeContent.find("~emoji.(");
            var beforeMusicalPos = beforeContent.find("~musical.(");
            "[DEBUG] BEFORE replace - doc.string.size: %".format(beforeContent.size).postln;
            "[DEBUG] BEFORE - emoji line byte pos: %, musical line byte pos: %".format(
                beforeEmojiPos, beforeMusicalPos
            ).postln;
            if (beforeEmojiPos.notNil and: { beforeMusicalPos.notNil }) {
                "[DEBUG] BEFORE - gap between lines: % bytes".format(
                    beforeMusicalPos - beforeEmojiPos
                ).postln;
            };
        }.value;

        doc.selectedString_(newValue);

        // Check IMMEDIATELY after replacement (no wait)
        "[DEBUG] IMMEDIATE after replace - selectionStart: %, selectionSize: %".format(
            doc.selectionStart, doc.selectionSize
        ).postln;

        // AFTER replacement: capture byte-level state
        {
            var afterContent = doc.string;
            var afterEmojiPos = afterContent.find("~emoji.(");
            var afterMusicalPos = afterContent.find("~musical.(");
            "[DEBUG] AFTER replace - doc.string.size: %".format(afterContent.size).postln;
            "[DEBUG] AFTER - emoji line byte pos: %, musical line byte pos: %".format(
                afterEmojiPos, afterMusicalPos
            ).postln;
            if (afterEmojiPos.notNil and: { afterMusicalPos.notNil }) {
                "[DEBUG] AFTER - gap between lines: % bytes".format(
                    afterMusicalPos - afterEmojiPos
                ).postln;
            };
            "[DEBUG] Size change: % bytes".format(afterContent.size - text.size).postln;
        }.value;
        // Find by pattern instead of using utf16 position (doc.string is bytes)
        {
            var immediateText = doc.string;
            var immediatePos = immediateText.find("~" ++ controllerName ++ ".(");
            if (immediatePos.notNil) {
                "[DEBUG] IMMEDIATE doc.string shows: '%'".format(
                    immediateText[immediatePos..((immediatePos + 30).min(immediateText.size - 1))]
                ).postln;
            } {
                "[DEBUG] IMMEDIATE: pattern '~%' not found in doc.string!".format(controllerName).postln;
            };
        }.value;

        // Force save and check document state
        "[DEBUG] doc.isEdited: %".format(doc.isEdited).postln;
        doc.save;
        "[DEBUG] After save, doc.isEdited: %".format(doc.isEdited).postln;

        // CRITICAL: Read disk IMMEDIATELY after save
        0.1.wait;  // Small delay for filesystem
        {
            var postSaveContent = File.readAllString(~targetPath);
            var postSavePos = postSaveContent.find("~" ++ controllerName ++ ".(");
            if (postSavePos.notNil) {
                "[DEBUG] IMMEDIATELY after save, DISK shows: '%'".format(
                    postSaveContent[postSavePos..((postSavePos + 30).min(postSaveContent.size - 1))]
                ).postln;
            } {
                "[DEBUG] IMMEDIATELY after save, pattern not on DISK!".postln;
            };
        }.value;

        // VERIFY: Re-read and check the result
        // Small delay to ensure document updates
        0.05.wait;
        verifyText = doc.string;
        expectedPattern = "~" ++ controllerName ++ ".(" ++ newValue ++ ");";

        // DEBUG: Show what we're searching for and in what
        patternPos = verifyText.find("~" ++ controllerName ++ ".(");
        if (patternPos.notNil) {
            snippet = verifyText[patternPos..((patternPos + 50).min(verifyText.size - 1))];
            "[DEBUG] After replace, doc.string shows: '%'".format(snippet).postln;
        };

        // CRITICAL: Compare in-memory vs on-disk content
        {
            var diskContent = File.readAllString(~targetPath);
            var diskPatternPos = diskContent.find("~" ++ controllerName ++ ".(");
            var diskSnippet;
            if (diskPatternPos.notNil) {
                diskSnippet = diskContent[diskPatternPos..((diskPatternPos + 50).min(diskContent.size - 1))];
                "[DEBUG] ON-DISK file shows: '%'".format(diskSnippet).postln;
            } {
                "[DEBUG] ON-DISK: pattern not found!".postln;
            };
            "[DEBUG] doc.string.size: %, disk.size: %".format(verifyText.size, diskContent.size).postln;
            if (verifyText.size != diskContent.size) {
                "[DEBUG] *** SIZE MISMATCH! In-memory vs disk differ by % bytes ***".format(
                    (verifyText.size - diskContent.size).abs
                ).postln;
            };
        }.value;

        "[DEBUG] Looking for: '%'".format(expectedPattern).postln;

        verified = verifyText.find(expectedPattern).notNil;
        "[DEBUG] find() returned: %".format(verifyText.find(expectedPattern)).postln;

        if (verified) {
            "[REPLACE] % → '%' VERIFIED".format(controllerName, newValue).postln;
        } {
            "[REPLACE] % VERIFICATION FAILED! Expected: '%'".format(controllerName, expectedPattern).postln;
        };

        verified;
    };
};

"[M2/M3] Helper ~replaceController defined".postln;
)

// ============================================================
// TEST 2.1: Basic replacement
// ============================================================

(
"[TEST 2.1] Basic replacement".postln;
{
    var ok = ~replaceController.(~targetDoc, "basic", "0.5");
    "[TEST 2.1] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// TEST 2.2: Varying lengths (position shift)
// ============================================================

(
"[TEST 2.2] Varying lengths - sequential".postln;
{
    var r1, r2;
    r1 = ~replaceController.(~targetDoc, "tiny", "1");
    0.1.wait;
    r2 = ~replaceController.(~targetDoc, "huge", "9999999999");
    "[TEST 2.2] tiny:%, huge:% → %".format(r1, r2, if(r1 && r2, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 2.3: Non-dot placeholders
// ============================================================

(
"[TEST 2.3] Non-dot placeholders".postln;
{
    var results = [];
    results = results.add(~replaceController.(~targetDoc, "letters", "REPLACED"));
    0.1.wait;
    results = results.add(~replaceController.(~targetDoc, "mixed", "42"));
    0.1.wait;
    results = results.add(~replaceController.(~targetDoc, "underscores", "___"));
    "[TEST 2.3] % → %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 2.4: Empty placeholder
// ============================================================

(
"[TEST 2.4] Empty placeholder".postln;
{
    var ok = ~replaceController.(~targetDoc, "empty", "FILLED");
    "[TEST 2.4] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// TEST 2.5: Spaces
// ============================================================

(
"[TEST 2.5] Spaced placeholder".postln;
{
    var ok = ~replaceController.(~targetDoc, "spaced", "no_spaces");
    "[TEST 2.5] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// TEST 2.6: Multiline (TRICKY)
// ============================================================

(
"[TEST 2.6] Multiline placeholder".postln;
{
    var ok = ~replaceController.(~targetDoc, "multiline", "single_line");
    "[TEST 2.6] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

//
  // ISOLATED EMOJI TEST - run after SETUP and HELPER blocks
  // ISOLATED EMOJI TEST - with proper Routine context
(
  {
      var ok = ~replaceController.(~targetDoc, "emoji", "0.3");
      "[TEST] emoji: %".format(if(ok, "PASS", "FAIL")).postln;
  }.fork(AppClock);
)
// ============================================================
// TEST 3.1: Unicode placeholders (UTF-16 conversion critical)
// ============================================================

(
"[TEST 3.1] Unicode placeholders".postln;
{
    var results = [];
    results = results.add(~replaceController.(~targetDoc, "arrows", "0.1"));
    0.1.wait;
    results = results.add(~replaceController.(~targetDoc, "korean", "0.2"));
    0.1.wait;
    results = results.add(~replaceController.(~targetDoc, "emoji", "0.3"));
    "[TEST 3.1] % → %".format(results, if(results.every{|x|x}, "PASS", "FAIL")).postln;
}.fork(AppClock);
)

// ============================================================
// TEST 3.2: After unicode (position drift accumulated)
// ============================================================

(
"[TEST 3.2] After unicode - drift test".postln;
{
    var ok = ~replaceController.(~targetDoc, "afterunicode", "DRIFTED");
    "[TEST 3.2] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// TEST 3.3: Nested parens
// ============================================================

(
"[TEST 3.3] Nested parens".postln;
{
    var ok = ~replaceController.(~targetDoc, "nested", "NESTED_OK");
    "[TEST 3.3] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// TEST 3.4: Musical symbols (non-BMP, surrogate pairs)
// ============================================================

(
"[TEST 3.4] Musical symbols (surrogate pairs)".postln;
{
    var ok = ~replaceController.(~targetDoc, "musical", "0.99");
    "[TEST 3.4] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// ADVERSARIAL TESTS
// ============================================================

// ADV 1: Semicolon in content
(
"[ADV 1] Semicolon in content".postln;
{
    var ok = ~replaceController.(~targetDoc, "semis", "OK");
    "[ADV 1] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ADV 2: Tilde pattern in content (tricky - might match wrong thing)
(
"[ADV 2] Tilde pattern in content".postln;
{
    var ok = ~replaceController.(~targetDoc, "meta", "META_OK");
    "[ADV 2] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ADV 3: Zero-width spaces
(
"[ADV 3] Zero-width spaces".postln;
{
    var ok = ~replaceController.(~targetDoc, "zerowidth", "ZW_OK");
    "[ADV 3] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ADV 4: Mixed BMP and non-BMP
(
"[ADV 4] Mixed BMP and non-BMP".postln;
{
    var ok = ~replaceController.(~targetDoc, "mixedplanes", "MIX_OK");
    "[ADV 4] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ADV 5: Special characters
(
"[ADV 5] Special characters".postln;
{
    var ok = ~replaceController.(~targetDoc, "special", "SPEC_OK");
    "[ADV 5] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// FINAL: Integrity check
// ============================================================

(
"[FINAL] End marker integrity".postln;
{
    var text = ~targetDoc.string;
    var ok = text.find("END_MARKER: OK").notNil;
    "[FINAL] %".format(if(ok, "PASS", "FAIL")).postln;
}.defer(0.3);
)

// ============================================================
// VERIFY: Print current state
// ============================================================

(
"[VERIFY] Current target:".postln;
{ ~targetDoc.string.postln; }.defer(0.3);
)

// ============================================================
// RESET: Restore original
// ============================================================

(
"[RESET] Restoring...".postln;
{
    var original = "// ============================================================
// M2/M3 TEST TARGET - Controllers to be modified
// ============================================================
// Edge cases for thorough testing.
// ============================================================

// === BASIC CASES ===
~basic.(.......);
~tiny.(..);
~huge.(....................);

// === NON-DOT PLACEHOLDERS ===
~letters.(xxxxxxxx);
~mixed.(a1b2c3d4);
~underscores.(________);

// === WHITESPACE ===
~empty.();
~spaced.(        );
~multiline.(....
....
....);

// === UNICODE (BMP - 3 byte UTF-8, 1 UTF-16) ===
~arrows.(→→→→);
~korean.(한글한글);

// === UNICODE (NON-BMP - 4 byte UTF-8, 2 UTF-16 surrogate pairs) ===
~emoji.(🎹🎹);
~musical.(𝄞𝄞𝄞);

// === AFTER UNICODE (drift test) ===
~afterunicode.(.....);

// === NESTED PARENS ===
~nested.(((.....)));

// === ADVERSARIAL: Semicolon in content ===
~semis.(a;b;c);

// === ADVERSARIAL: Tilde pattern in content ===
~meta.(~fake.(xxx));

// === ADVERSARIAL: Zero-width spaces (U+200B between letters) ===
~zerowidth.(a​b​c);
// === ADVERSARIAL: Mixed BMP and non-BMP ===
~mixedplanes.(한🎵글🎵);

// === ADVERSARIAL: Special chars (no escaping issues) ===
~special.(<>[]{}!@#$%);

// END_MARKER: OK
";
    var text = ~targetDoc.string;
    var utf16Len = ~byteToUtf16.(text, text.size);
    ~targetDoc.selectRange(0, utf16Len);
    ~targetDoc.selectedString_(original);
    "[RESET] Done".postln;
}.defer(0.3);
)
