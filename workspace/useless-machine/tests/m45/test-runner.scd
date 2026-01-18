// ============================================================
// M4.5 TEST RUNNER - Cursor Preservation During Same-Document Edits
// ============================================================
// Tests that document modifications don't disrupt user's cursor position.
// ============================================================

// ============================================================
// SETUP: Converter functions (from M09)
// ============================================================

(
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

"[M4.5] Converter functions loaded".postln;
)

// ============================================================
// SETUP: Get target document handle
// ============================================================

(
var m45Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var targetFilename = "test-target.scd";
var runnerFilename = "test-runner.scd";

~m45Dir = m45Dir;
~m45TargetPath = m45Dir +/+ targetFilename;

// Try to find already-open document first (no focus steal)
~m45Doc = Document.allDocuments.detect { |doc|
    doc.title == targetFilename
};

if (~m45Doc.isNil) {
    var currentDoc = Document.current;
    ~m45Doc = Document.open(~m45TargetPath);
    currentDoc.front;
    "[M4.5] Opened target (returned focus)".postln;
} {
    "[M4.5] Found target in allDocuments".postln;
};

// VALIDATION: Make sure we're not pointing at the runner!
if (~m45Doc.notNil and: { ~m45Doc.title == runnerFilename }) {
    "!!! ERROR: ~m45Doc points to runner, not target !!!".postln;
    "!!! Open test-target.scd manually first !!!".postln;
    ~m45Doc = nil;
} {
    "[M4.5] Setup complete".postln;
    "[M4.5] Target doc title: %".format(~m45Doc.title).postln;
    "[M4.5] Target doc path: %".format(~m45Doc.path).postln;
};
)

// ============================================================
// API PROBE 4.5.0a: Does doc.string have a setter with range?
// ============================================================
// According to SC docs: string(string, rangestart, rangesize)
// "Gets or sets the string within a certain range."
// SKIP: This API doesn't exist in the IDE's Document implementation.
// The sclang Document class only has the getter version.
// Confirmed by testing: it just returns a substring, doesn't set.

(
"[PROBE 4.5.0a] SKIPPED - doc.string(text, start, len) is getter-only".postln;
"[PROBE 4.5.0a] Result: Must use save/restore approach instead".postln;
)

// ============================================================
// API PROBE 4.5.0b: Can we save/restore cursor position?
// ============================================================

(
"[PROBE 4.5.0b] Testing selectionStart save/restore...".postln;
{
    var doc = ~m45Doc;
    var savedStart, savedSize;
    var restoredStart, restoredSize;

    0.2.wait;

    // Set cursor to a known position (UTF-16 position 100)
    doc.selectRange(100, 0);
    0.1.wait;

    // Save position
    savedStart = doc.selectionStart;
    savedSize = doc.selectionSize;
    "[PROBE 4.5.0b] Saved: start=%, size=%".format(savedStart, savedSize).postln;

    // Move cursor elsewhere (simulate edit operation)
    doc.selectRange(50, 10);
    0.1.wait;

    "[PROBE 4.5.0b] After move: start=%, size=%".format(
        doc.selectionStart, doc.selectionSize
    ).postln;

    // Restore position
    doc.selectRange(savedStart, savedSize);
    0.1.wait;

    restoredStart = doc.selectionStart;
    restoredSize = doc.selectionSize;
    "[PROBE 4.5.0b] Restored: start=%, size=%".format(restoredStart, restoredSize).postln;

    if ((restoredStart == savedStart) && (restoredSize == savedSize)) {
        "[PROBE 4.5.0b] PASS - Position restore works!".postln;
    } {
        "[PROBE 4.5.0b] FAIL - Position restore failed".postln;
    };
}.fork(AppClock);
)

// ============================================================
// API PROBE 4.5.0c: Does editing change cursor position?
// ============================================================
// Verify the problem we're trying to solve

(
"[PROBE 4.5.0c] Verifying that selectRange+selectedString_ moves cursor...".postln;
{
    var doc = ~m45Doc;
    var text, pattern, patternPos;
    var contentStart, contentEnd, depth;
    var utf16Start, utf16Len;
    var cursorBefore, cursorAfter;

    0.2.wait;

    // Set cursor to position 300 (away from any controller)
    doc.selectRange(300, 0);
    0.1.wait;
    cursorBefore = doc.selectionStart;
    "[PROBE 4.5.0c] Cursor before edit: %".format(cursorBefore).postln;

    // Now do a selectRange+selectedString_ operation on ~top controller
    text = doc.string;
    pattern = "~top.(";
    patternPos = text.find(pattern);

    if (patternPos.notNil) {
        // Use paren-depth counting to find matching close paren
        // (same logic as helper - don't just find first ")")
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

        "[PROBE 4.5.0c] Selecting utf16 % len %".format(utf16Start, utf16Len).postln;

        doc.selectRange(utf16Start, utf16Len);
        doc.selectedString_("TEST");
        0.1.wait;

        cursorAfter = doc.selectionStart;
        "[PROBE 4.5.0c] Cursor after edit: %".format(cursorAfter).postln;

        if (cursorAfter != cursorBefore) {
            "[PROBE 4.5.0c] CONFIRMED - Edit moved cursor from % to %".format(
                cursorBefore, cursorAfter
            ).postln;
        } {
            "[PROBE 4.5.0c] UNEXPECTED - Cursor stayed at same position!".postln;
        };
    } {
        "[PROBE 4.5.0c] ERROR - Could not find ~top controller".postln;
    };
}.fork(AppClock);
)

// ============================================================
// HELPER: Replace with cursor preservation
// ============================================================

(
~m45ReplacePreserveCursor = { |doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd;
    var utf16Start, utf16Len;
    var savedCursorStart, savedCursorSize;
    var lengthDelta;

    // Save current cursor position
    savedCursorStart = doc.selectionStart;
    savedCursorSize = doc.selectionSize;

    // Find and replace
    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4.5-REPLACE] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        var depth = 1;
        contentStart = patternPos + pattern.size;
        contentEnd = contentStart;

        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };

        utf16Start = ~byteToUtf16.(text, contentStart);
        utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

        // Calculate length change for cursor adjustment
        lengthDelta = newValue.size - utf16Len;

        // Do the replacement
        doc.selectRange(utf16Start, utf16Len);
        doc.selectedString_(newValue);

        // Restore cursor position with adjustment
        // If cursor was AFTER the edit location, adjust by length delta
        // If cursor was BEFORE the edit, no adjustment needed
        // If cursor was INSIDE the edit region, place at end of new content
        if (savedCursorStart >= (utf16Start + utf16Len)) {
            // Cursor was after edit region - adjust
            doc.selectRange(savedCursorStart + lengthDelta, savedCursorSize);
        } {
            if (savedCursorStart >= utf16Start) {
                // Cursor was inside edit region - place at end of new content
                doc.selectRange(utf16Start + newValue.size, 0);
            } {
                // Cursor was before edit region - no adjustment
                doc.selectRange(savedCursorStart, savedCursorSize);
            };
        };

        "[M4.5-REPLACE] % -> '%%' (cursor restored)".format(
            controllerName, newValue, ""
        ).postln;
        true;
    };
};

"[M4.5] Helper ~m45ReplacePreserveCursor defined".postln;
)

// ============================================================
// HELPER: Verify controller value
// ============================================================

(
~m45Verify = { |doc, controllerName, expectedValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth, actual;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[M4.5-VERIFY] Controller '%' not found".format(controllerName).postln;
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
            "[M4.5-VERIFY] % == '%' OK".format(controllerName, expectedValue).postln;
            true;
        } {
            "[M4.5-VERIFY] % MISMATCH: expected '%', got '%'".format(
                controllerName, expectedValue, actual
            ).postln;
            false;
        };
    };
};

"[M4.5] Helper ~m45Verify defined".postln;
)

// ============================================================
// TEST 4.5a: Cursor BEFORE edit location
// ============================================================
// User cursor at line 5, edit happens at line 15
// Expected: cursor stays at line 5 (same position)

(
"[TEST 4.5a] Cursor before edit location".postln;
{
    var doc = ~m45Doc;
    var text, topPos;
    var cursorPosBefore = 50;  // Near start of file
    var cursorPosAfter;

    0.2.wait;

    // Set cursor at position 50 (before any controller)
    doc.selectRange(cursorPosBefore, 0);
    0.1.wait;

    "[TEST 4.5a] Cursor set to: %".format(doc.selectionStart).postln;

    // Edit ~bottom (which is after position 50)
    ~m45ReplacePreserveCursor.(doc, "bottom", "BEFORE_TEST");
    0.1.wait;

    cursorPosAfter = doc.selectionStart;
    "[TEST 4.5a] Cursor after edit: %".format(cursorPosAfter).postln;

    // Verify cursor stayed in place
    if (cursorPosAfter == cursorPosBefore) {
        // Also verify the edit worked
        if (~m45Verify.(doc, "bottom", "BEFORE_TEST")) {
            "[TEST 4.5a] PASS - Cursor preserved at %".format(cursorPosAfter).postln;
        } {
            "[TEST 4.5a] FAIL - Cursor OK but edit verification failed".postln;
        };
    } {
        "[TEST 4.5a] FAIL - Cursor moved from % to %".format(
            cursorPosBefore, cursorPosAfter
        ).postln;
    };
}.fork(AppClock);
)

// ============================================================
// TEST 4.5b: Cursor AFTER edit location
// ============================================================
// User cursor at line 20, edit happens at line 5
// Expected: cursor adjusted for length change

(
"[TEST 4.5b] Cursor after edit location".postln;
{
    var doc = ~m45Doc;
    var text, pattern, patternPos;
    var cursorPosBefore, cursorPosAfter, expectedPosAfter;
    var topOldLen, topNewValue, lengthDelta;
    var contentStart, contentEnd, depth;

    0.2.wait;

    // First, find the length of ~top's content to predict adjustment
    text = doc.string;
    pattern = "~top.(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[TEST 4.5b] ERROR - ~top controller not found".postln;
    } {
        // Calculate content bounds
        contentStart = patternPos + pattern.size;
        contentEnd = contentStart;
        depth = 1;
        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };
        topOldLen = ~byteToUtf16.(text, contentEnd) - ~byteToUtf16.(text, contentStart);

        "[TEST 4.5b] ~top old content UTF-16 length: %".format(topOldLen).postln;
        "[TEST 4.5b] ~top edit region: utf16 % to %".format(
            ~byteToUtf16.(text, contentStart),
            ~byteToUtf16.(text, contentEnd)
        ).postln;

        // Set cursor AFTER the ~top controller (in the padding text below it)
        // ~top ends around position 420, so 500 should be safely after
        cursorPosBefore = 500;
        doc.selectRange(cursorPosBefore, 0);
        0.1.wait;

        "[TEST 4.5b] Cursor set to: %".format(doc.selectionStart).postln;

        // Edit ~top with different length content
        topNewValue = "AFTER_TEST_123";
        lengthDelta = topNewValue.size - topOldLen;
        expectedPosAfter = cursorPosBefore + lengthDelta;

        "[TEST 4.5b] Expected cursor adjustment: % + % = %".format(
            cursorPosBefore, lengthDelta, expectedPosAfter
        ).postln;

        ~m45ReplacePreserveCursor.(doc, "top", topNewValue);
        0.1.wait;

        cursorPosAfter = doc.selectionStart;
        "[TEST 4.5b] Cursor after edit: %".format(cursorPosAfter).postln;

        // Verify cursor was adjusted correctly
        if (cursorPosAfter == expectedPosAfter) {
            if (~m45Verify.(doc, "top", topNewValue)) {
                "[TEST 4.5b] PASS - Cursor adjusted from % to %".format(
                    cursorPosBefore, cursorPosAfter
                ).postln;
            } {
                "[TEST 4.5b] FAIL - Cursor OK but edit verification failed".postln;
            };
        } {
            "[TEST 4.5b] FAIL - Cursor at % (expected %)".format(
                cursorPosAfter, expectedPosAfter
            ).postln;
        };
    };
}.fork(AppClock);
)

// ============================================================
// TEST 4.5c: Cursor INSIDE edit region
// ============================================================
// User cursor is inside the controller being mutated
// Expected: cursor placed at end of new content

(
"[TEST 4.5c] Cursor inside edit region".postln;
{
    var doc = ~m45Doc;
    var text, pattern, patternPos, contentStart, utf16Start;
    var cursorPosAfter;

    0.2.wait;
    text = doc.string;

    // Find ~middle and place cursor inside its content
    pattern = "~middle.(";
    patternPos = text.find(pattern);

    if (patternPos.notNil) {
        contentStart = patternPos + pattern.size;
        utf16Start = ~byteToUtf16.(text, contentStart);

        // Place cursor 3 characters into the content
        doc.selectRange(utf16Start + 3, 0);
        0.1.wait;

        "[TEST 4.5c] Cursor set inside ~middle at: %".format(doc.selectionStart).postln;

        // Edit ~middle
        ~m45ReplacePreserveCursor.(doc, "middle", "INSIDE");
        0.1.wait;

        cursorPosAfter = doc.selectionStart;
        "[TEST 4.5c] Cursor after edit: %".format(cursorPosAfter).postln;

        // Expected: cursor at end of new content (utf16Start + "INSIDE".size)
        if (cursorPosAfter == (utf16Start + "INSIDE".size)) {
            if (~m45Verify.(doc, "middle", "INSIDE")) {
                "[TEST 4.5c] PASS - Cursor placed at end of new content".postln;
            } {
                "[TEST 4.5c] FAIL - Cursor OK but edit verification failed".postln;
            };
        } {
            "[TEST 4.5c] FAIL - Cursor at % (expected %)".format(
                cursorPosAfter, utf16Start + "INSIDE".size
            ).postln;
        };
    } {
        "[TEST 4.5c] ERROR - Could not find ~middle controller".postln;
    };
}.fork(AppClock);
)

// ============================================================
// TEST 4.5d: Active selection preserved
// ============================================================
// User has text selected, edit happens elsewhere
// Expected: selection preserved (with adjustment if needed)

(
"[TEST 4.5d] Active selection preserved".postln;
{
    var doc = ~m45Doc;
    var selStartBefore = 50;
    var selSizeBefore = 20;
    var selStartAfter, selSizeAfter;

    0.2.wait;

    // Set selection at position 50-70 (before ~middle)
    doc.selectRange(selStartBefore, selSizeBefore);
    0.1.wait;

    "[TEST 4.5d] Selection set: start=%, size=%".format(
        doc.selectionStart, doc.selectionSize
    ).postln;

    // Edit ~bottom (which is after the selection)
    ~m45ReplacePreserveCursor.(doc, "bottom", "SEL_TEST");
    0.1.wait;

    selStartAfter = doc.selectionStart;
    selSizeAfter = doc.selectionSize;

    "[TEST 4.5d] Selection after edit: start=%, size=%".format(
        selStartAfter, selSizeAfter
    ).postln;

    // Selection should be unchanged (edit was after selection)
    if ((selStartAfter == selStartBefore) && (selSizeAfter == selSizeBefore)) {
        if (~m45Verify.(doc, "bottom", "SEL_TEST")) {
            "[TEST 4.5d] PASS - Selection preserved".postln;
        } {
            "[TEST 4.5d] FAIL - Selection OK but edit verification failed".postln;
        };
    } {
        "[TEST 4.5d] FAIL - Selection changed from %,% to %,%".format(
            selStartBefore, selSizeBefore, selStartAfter, selSizeAfter
        ).postln;
    };
}.fork(AppClock);
)

// ============================================================
// RESET: Restore original test-target.scd
// ============================================================

(
"[RESET] Restoring test-target.scd...".postln;
{
    var original = "// ============================================================
// M4.5 TEST TARGET - Cursor Preservation
// ============================================================
// Fixture file for testing cursor preservation during edits.
// DO NOT manually edit this file during tests.
// ============================================================

// === CONTROLLER: TOP ===
~top.(.......);

// === SOME PADDING TEXT ===
// This is filler text to create distance between controllers.
// The cursor will be positioned here during some tests.
// More lines to provide selection space.
// CURSOR_ANCHOR_1: place cursor here for tests
// Even more padding.

// === CONTROLLER: MIDDLE ===
~middle.(.........);

// === MORE PADDING ===
// Additional filler text.
// CURSOR_ANCHOR_2: another test position
// Testing cursor preservation.

// === CONTROLLER: BOTTOM ===
~bottom.(.....);

// END_MARKER: OK";
    var doc = ~m45Doc;
    var text, utf16Len;

    0.2.wait;
    text = doc.string;
    utf16Len = ~byteToUtf16.(text, text.size);
    doc.selectRange(0, utf16Len);
    doc.selectedString_(original);
    "[RESET] Done".postln;
}.fork(AppClock);
)
