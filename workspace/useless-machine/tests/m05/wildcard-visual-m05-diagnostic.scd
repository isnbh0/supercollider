// ============================================================
// MILESTONE 0.5: COORDINATE SYSTEM DIAGNOSTIC
// ============================================================
// Minimal file to understand doc.string vs doc.selectRange
// ============================================================

// Some test content with unicode:
// Arrow: → (U+2192)
// Korean: 한글
// Emoji: 🎹

// A known target string we'll try to select:
// TARGET_DOTS: ".........."

// POSITION MARKERS (unique strings for test 0.5f):
// [###MARK_FOUR_HUNDRED###]
// [###MARK_FIVE_HUNDRED###]

// ==================== TEST 0.5a ====================
// Basic sanity check at start of file
(
var doc = Document.current;
var text = doc.string;

"".postln;
"=== TEST 0.5a: Basic sanity at file start ===".postln;
"doc.string.size: %".format(text.size).postln;

// Select first 10 chars
doc.selectRange(0, 10);
"selectRange(0,10): '%'".format(doc.selectedString).postln;
"text[0..9]:        '%'".format(text[0..9]).postln;
"Match: %".format(doc.selectedString == text[0..9]).postln;
)

// ==================== TEST 0.5b ====================
// Find all non-ASCII bytes
(
var doc = Document.current;
var text = doc.string;
var nonAscii = List.new;

"".postln;
"=== TEST 0.5b: Find non-ASCII bytes ===".postln;

text.do {|char, i|
    var code = char.ascii;
    if(code < 0 or: { code > 127 }, {
        nonAscii.add([i, code, char]);
    });
};

"Found % non-ASCII bytes".format(nonAscii.size).postln;
nonAscii.do {|item|
    "  pos %: ascii=% char='%'".format(item[0], item[1], item[2]).postln;
};
)

// ==================== TEST 0.5c ====================
// Measure drift at multiple positions
(
var doc = Document.current;
var text = doc.string;

"".postln;
"=== TEST 0.5c: Drift at various positions ===".postln;
"pos    | string[pos] | selectRange | match".postln;
"-------+-------------+-------------+------".postln;

[0, 10, 50, 100, 150, 200, 250, 300, 400, 500].do {|pos|
    var expected, actual;
    if(pos < text.size, {
        expected = text[pos..pos+4];
        doc.selectRange(pos, 5);
        actual = doc.selectedString;
        "% | '%' | '%' | %".format(
            pos.asString.padLeft(6),
            expected.padRight(11),
            actual.padRight(11),
            expected == actual
        ).postln;
    });
};
)

// ==================== TEST 0.5d ====================
// Find exactly where drift starts
(
var doc = Document.current;
var text = doc.string;
var firstMismatch = nil;

"".postln;
"=== TEST 0.5d: Find first mismatch ===".postln;

text.size.min(1000).do {|pos|
    var expected, actual;
    if(firstMismatch.isNil, {
        expected = text[pos..pos];
        doc.selectRange(pos, 1);
        actual = doc.selectedString;
        if(expected != actual, {
            firstMismatch = pos;
        });
    });
};

if(firstMismatch.isNil, {
    "No mismatch in first 1000 chars!".postln;
}, {
    "FIRST MISMATCH at position %".format(firstMismatch).postln;
    "  text[%]: '%' (ascii %)".format(
        firstMismatch,
        text[firstMismatch],
        text[firstMismatch].ascii
    ).postln;
    doc.selectRange(firstMismatch, 1);
    "  selectRange(%,1): '%'".format(firstMismatch, doc.selectedString).postln;
    "".postln;
    "  Context around mismatch:".postln;
    "  text[%-10..%+10]: '%'".format(
        firstMismatch, firstMismatch,
        text[(firstMismatch-10).max(0)..(firstMismatch+10).min(text.size-1)]
    ).postln;
});
)

// ==================== TEST 0.5e ====================
// Try to select TARGET_DOTS
(
var doc = Document.current;
var text = doc.string;
var target = "..........";
var stringPos = text.find("TARGET_DOTS:");
var dotsPos, selected;

"".postln;
"=== TEST 0.5e: Find and select TARGET_DOTS ===".postln;

if(stringPos.notNil, {
    dotsPos = text.find(target, false, stringPos);
    if(dotsPos.notNil, {
        "Found dots at string position %".format(dotsPos).postln;
        "text[%..%]: '%'".format(dotsPos, dotsPos+9, text[dotsPos..dotsPos+9]).postln;

        doc.selectRange(dotsPos, 10);
        selected = doc.selectedString;
        "selectRange(%, 10): '%'".format(dotsPos, selected).postln;
        "Match: %".format(selected == target).postln;

        if(selected != target, {
            // Find where selection actually landed
            var actualPos = text.find(selected);
            "".postln;
            "Selection actually landed at string position: %".format(actualPos).postln;
            if(actualPos.notNil, {
                "Drift: % - % = %".format(dotsPos, actualPos, dotsPos - actualPos).postln;
            });
        });
    }, {
        "Could not find dots after TARGET_DOTS marker".postln;
    });
}, {
    "Could not find TARGET_DOTS marker".postln;
});
)

// ==================== TEST 0.5f ====================
// Reverse: select, then find in string
// Using unique markers at known byte positions
(
var doc = Document.current;
var text = doc.string;
// Byte positions of markers (from python analysis):
// MARK_FOUR_HUNDRED at byte 527, MARK_FIVE_HUNDRED at byte 556
var testPositions = [100, 300, 527, 556];

"".postln;
"=== TEST 0.5f: Reverse lookup with unique markers ===".postln;
"Testing byte positions: 100, 300, 527 (FOUR), 556 (FIVE)".postln;
"".postln;

testPositions.do {|selectPos|
    var selected, foundAt, drift;
    doc.selectRange(selectPos, 17);  // 17 chars to capture MARK_XXXX_HUNDRED
    selected = doc.selectedString;
    foundAt = text.find(selected);
    "selectRange(%, 17):".format(selectPos).postln;
    "  selected: '%'".format(selected.replace("\n", "\\n")).postln;
    if(foundAt.notNil, {
        "  found at byte: %".format(foundAt).postln;
        "  drift (selectPos - bytePos): %".format(selectPos - foundAt).postln;
    }, {
        "  NOT FOUND in text.find()".postln;
    });
    "".postln;
};
)

// ==================== SUMMARY ====================
(
"".postln;
"=== DIAGNOSTIC SUMMARY ===".postln;
"Run tests 0.5a through 0.5f and report results.".postln;
"Key questions:".postln;
"  1. Does drift exist at position 0?".postln;
"  2. Where does drift first appear?".postln;
"  3. Is drift constant or cumulative?".postln;
"  4. Does drift correlate with non-ASCII byte count?".postln;
)
