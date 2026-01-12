// ============================================================
// WILDCARD VISUAL MODE - MILESTONE 0: API CAPABILITY PROBING
// ============================================================
//
// PURPOSE: Verify the Document API actually works as documented.
// RUN EACH TEST BLOCK INDIVIDUALLY (Cmd+Enter on the block)
// RECORD RESULTS in wildcard-visual-impl-log.md
//
// IMPORTANT: Run these tests with soundtest.scd OPEN in the IDE
// ============================================================

// ==================== TEST 0.1 ====================
// Does Document.current return something?
(
var doc = Document.current;
"".postln;
"=== TEST 0.1: Document.current exists ===".postln;
if(doc.isNil, {
    "FAIL: Document.current is nil".postln;
}, {
    "PASS: Document.current = %".format(doc).postln;
    "  class: %".format(doc.class).postln;
    "  path: %".format(doc.path).postln;
});
"".postln;
)

// ==================== TEST 0.2 ====================
// Can we read document text?
(
var doc = Document.current;
var text;

"".postln;
"=== TEST 0.2: Can we read document text? ===".postln;

if(doc.isNil, {
    "SKIP: Document.current is nil (run Test 0.1 first)".postln;
}, {
    // Try synchronous first
    try {
        text = doc.string;
        if(text.isNil, {
            "WARN: doc.string returned nil".postln;
        }, {
            "PASS: doc.string works, length = %".format(text.size).postln;
            "  first 50 chars: '%'".format(text[0..49].asString).postln;
        });
    } { |error|
        "FAIL: doc.string threw: %".format(error).postln;
        "  -> try getTextAsync as fallback".postln;
    };
});
"".postln;
)

// ==================== TEST 0.3 ====================
// Can we get selection info?
(
var doc = Document.current;

"".postln;
"=== TEST 0.3: Can we get selection info? ===".postln;

if(doc.isNil, {
    "SKIP: Document.current is nil".postln;
}, {
    "selectionStart: %".format(doc.selectionStart).postln;
    "selectionSize: %".format(doc.selectionSize).postln;
    if(doc.selectionStart.isInteger and: doc.selectionSize.isInteger, {
        "PASS: Selection info returns integers".postln;
    }, {
        "FAIL: Selection info not integers".postln;
    });
});
"".postln;
)

// ==================== TEST 0.4 ====================
// Can we SET a selection range?
// This should select characters 10-20 in the document
(
var doc = Document.current;

"".postln;
"=== TEST 0.4: Can we SET a selection range? ===".postln;

if(doc.isNil, {
    "SKIP: Document.current is nil".postln;
}, {
    "Before: selectionStart = %".format(doc.selectionStart).postln;
    doc.selectRange(10, 10);
    "After selectRange(10, 10):".postln;
    "  selectionStart: %".format(doc.selectionStart).postln;
    "  selectionSize: %".format(doc.selectionSize).postln;

    if(doc.selectionStart == 10 and: { doc.selectionSize == 10 }, {
        "PASS: selectRange works".postln;
    }, {
        "CHECK: Look at IDE - is text selected?".postln;
        "  If yes but values differ, PARTIAL PASS".postln;
        "  If nothing selected, FAIL".postln;
    });
});
"".postln;
)

// ==================== TEST 0.5 ====================
// Can we REPLACE selected text?
// WARNING: This WILL modify your document!
// First, manually select some text in THIS document, then run:
(
var doc = Document.current;
var before;

"".postln;
"=== TEST 0.5: Can we REPLACE selected text? ===".postln;
"WARNING: This modifies the document! Cmd+Z to undo.".postln;

if(doc.isNil, {
    "SKIP: Document.current is nil".postln;
}, {
    // First select something predictable
    doc.selectRange(0, 2);  // Select first 2 chars
    before = doc.selectedString;
    "Before: '%'".format(before).postln;

    doc.selectedString_("XX");
    "After replacement...".postln;
    "  Check document - did first 2 chars become 'XX'?".postln;

    if(doc.string[0..1] == "XX", {
        "PASS: selectedString_ works".postln;
    }, {
        "CHECK: Visual inspection required".postln;
    });

    "Press Cmd+Z NOW to undo!".postln;
});
"".postln;
)

// ==================== TEST 0.6 ====================
// Can we execute a string?
(
var code = "1 + 2 + 3";
var result;

"".postln;
"=== TEST 0.6: Can we execute a string? ===".postln;

result = code.interpret;
"'%'.interpret = %".format(code, result).postln;

if(result == 6, {
    "PASS: String.interpret works".postln;
}, {
    "FAIL: Expected 6, got %".format(result).postln;
});
"".postln;
)

// ==================== SUMMARY ====================
// Run this after completing all tests above
(
"".postln;
"=== MILESTONE 0 SUMMARY ===".postln;
"".postln;
"Fill in results in wildcard-visual-impl-log.md:".postln;
"".postln;
"| Test | Description | Status | Notes |".postln;
"|------|-------------|--------|-------|".postln;
"| 0.1 | Document.current exists | ____ | |".postln;
"| 0.2 | doc.string readable | ____ | |".postln;
"| 0.3 | selectionStart/Size | ____ | |".postln;
"| 0.4 | selectRange works | ____ | |".postln;
"| 0.5 | selectedString_ replacement | ____ | |".postln;
"| 0.6 | String.interpret works | ____ | |".postln;
"".postln;
"EXIT CRITERIA: ALL tests must PASS to proceed to Milestone 1".postln;
"".postln;
)
