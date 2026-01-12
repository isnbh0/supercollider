// ============================================================
// M1.5 TEST SOURCE - "The Orchestrator"
// ============================================================
// This file loads code from test-changer-logic.scd and executes it.
// The loaded code will attempt to modify various documents.
// ============================================================

// MARKER_SOURCE: <<<UNCHANGED>>>

// ============================================================
// TEST 1.5a: Loaded code modifies THIS file (the caller)
// ============================================================
// The changer will look for MARKER_SOURCE and change <<<UNCHANGED>>> to <<<CHANGED>>>

(
var m15Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Dir = m15Dir +/+ "../m09/";
var changerLogic;

"[M1.5a] Testing: loaded code modifies caller document".postln;

// Load converter module
(m09Dir +/+ "wildcard-visual-m09-module.scd").load;

// Load the changer code (returns a function)
changerLogic = (m15Dir +/+ "test-changer-logic.scd").load;

// Execute with target = this file
changerLogic.value(
    targetPath: thisProcess.nowExecutingPath,
    markerPrefix: "MARKER_SOURCE",
    oldValue: "<<<UNCHANGED>>>",
    newValue: "<<<CHANGED>>>"
);
)

// ============================================================
// TEST 1.5b: Loaded code modifies ITSELF
// ============================================================
// Run this after resetting test-changer-logic.scd

(
var m15Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Dir = m15Dir +/+ "../m09/";
var changerLogic;

"[M1.5b] Testing: loaded code self-modifies".postln;

(m09Dir +/+ "wildcard-visual-m09-module.scd").load;
changerLogic = (m15Dir +/+ "test-changer-logic.scd").load;

changerLogic.value(
    targetPath: m15Dir +/+ "test-changer-logic.scd",
    markerPrefix: "MARKER_CHANGER",
    oldValue: "<<<UNCHANGED>>>",
    newValue: "<<<CHANGED>>>"
);
)

// ============================================================
// TEST 1.5c: Loaded code modifies THIRD file
// ============================================================

(
var m15Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Dir = m15Dir +/+ "../m09/";
var changerLogic;

"[M1.5c] Testing: loaded code modifies third file".postln;

(m09Dir +/+ "wildcard-visual-m09-module.scd").load;
changerLogic = (m15Dir +/+ "test-changer-logic.scd").load;

changerLogic.value(
    targetPath: m15Dir +/+ "test-utilities.scd",
    markerPrefix: "MARKER_UTIL",
    oldValue: "<<<UNCHANGED>>>",
    newValue: "<<<CHANGED>>>"
);
)

// ============================================================
// TEST 1.5d: Multiple Document handles simultaneously
// ============================================================

(
var m15Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var docSource, docChanger, docUtil;

"[M1.5d] Testing: multiple Document handles".postln;

// Open all three documents
docSource = Document.open(thisProcess.nowExecutingPath);
docChanger = Document.open(m15Dir +/+ "test-changer-logic.scd");
docUtil = Document.open(m15Dir +/+ "test-utilities.scd");

// Defer to ensure documents are ready
{
    var allValid = [docSource, docChanger, docUtil].every { |doc| doc.notNil };
    "[M1.5d] All handles valid: %".format(allValid).postln;

    "[M1.5d] docSource: %".format(docSource).postln;
    "[M1.5d] docChanger: %".format(docChanger).postln;
    "[M1.5d] docUtil: %".format(docUtil).postln;

    // Test: can we read from non-current?
    "[M1.5d] docChanger.string.size: %".format(docChanger.string.size).postln;

    // Test: which is current?
    "[M1.5d] Document.current: %".format(Document.current).postln;
}.defer(0.5);
)

// ============================================================
// TEST 1.5e: Modify WITHOUT stealing focus
// ============================================================
// Key question: can we modify a background document?

(
var m15Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Dir = m15Dir +/+ "../m09/";
var targetDoc, originalCurrent;

"[M1.5e] Testing: modify without stealing focus".postln;

(m09Dir +/+ "wildcard-visual-m09-module.scd").load;

// Record which doc has focus now
originalCurrent = Document.current;
"[M1.5e] Original current: %".format(originalCurrent.title).postln;

// Get handle to target (will steal focus)
targetDoc = Document.open(m15Dir +/+ "test-utilities.scd");

{
    var text, bytePos, utf16Pos, utf16Len;
    var searchPattern = "MARKER_UTIL: <<<UNCHANGED>>>";
    var replacePattern = "MARKER_UTIL: <<<CHANGED>>>";

    // Return focus to original
    originalCurrent.front;

    // Now try to modify targetDoc while it's in background
    0.3.wait;

    "[M1.5e] After .front, current: %".format(Document.current.title).postln;

    text = targetDoc.string;
    bytePos = text.find(searchPattern);

    if (bytePos.notNil) {
        utf16Pos = ~byteToUtf16.(text, bytePos);
        utf16Len = ~byteToUtf16.(text, bytePos + searchPattern.size) - utf16Pos;

        // THE KEY TEST: modify while not focused
        targetDoc.selectRange(utf16Pos, utf16Len);
        targetDoc.selectedString_(replacePattern);

        "[M1.5e] Modified. Current after modify: %".format(Document.current.title).postln;
        "[M1.5e] Did focus stay? %".format(Document.current == originalCurrent).postln;
    } {
        "[M1.5e] Pattern not found (already changed?)".postln;
    };
}.fork(AppClock);
)

// ============================================================
// TEST 1.5f: Use Document.allDocuments to avoid open()
// ============================================================
// Check if we can get handles without Document.open stealing focus

(
"[M1.5f] Testing: Document.allDocuments".postln;

Document.allDocuments.do { |doc, i|
    "[M1.5f] Doc %: %".format(i, doc.title).postln;
};

// Can we find by path?
~findDocByPath = { |path|
    var filename = PathName(path).fileName;
    Document.allDocuments.detect { |doc| doc.title == filename };
};

"[M1.5f] Looking for test-utilities.scd...".postln;
~foundDoc = ~findDocByPath.(PathName(thisProcess.nowExecutingPath).pathOnly +/+ "test-utilities.scd");
"[M1.5f] Found: %".format(~foundDoc).postln;
)

// ============================================================
// RESET: Restore all markers to <<<UNCHANGED>>>
// ============================================================

(
var m15Dir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Dir = m15Dir +/+ "../m09/";

"[M1.5 RESET] Restoring all markers...".postln;

(m09Dir +/+ "wildcard-visual-m09-module.scd").load;

~resetMarker = { |path, markerPrefix|
    var doc = Document.open(path);
    {
        var text = doc.string;
        var searchPattern = markerPrefix ++ ": <<<CHANGED>>>";
        var replacePattern = markerPrefix ++ ": <<<UNCHANGED>>>";
        var bytePos = text.find(searchPattern);

        if (bytePos.notNil) {
            var utf16Pos = ~byteToUtf16.(text, bytePos);
            var utf16Len = ~byteToUtf16.(text, bytePos + searchPattern.size) - utf16Pos;
            doc.selectRange(utf16Pos, utf16Len);
            doc.selectedString_(replacePattern);
            "[RESET] % in %".format(markerPrefix, PathName(path).fileName).postln;
        } {
            "[RESET] % not found or already reset in %".format(markerPrefix, PathName(path).fileName).postln;
        };
    }.defer(0.3);
};

~resetMarker.(thisProcess.nowExecutingPath, "MARKER_SOURCE");
~resetMarker.(m15Dir +/+ "test-changer-logic.scd", "MARKER_CHANGER");
~resetMarker.(m15Dir +/+ "test-utilities.scd", "MARKER_UTIL");

"[M1.5 RESET] Done (check each file)".postln;
)
