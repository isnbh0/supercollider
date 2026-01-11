// ============================================================
// MILESTONE 0.9: BYTE ↔ UTF-16 POSITION CONVERTER
// ============================================================
// This utility converts between:
//   - Byte positions (used by SC String indexing)
//   - UTF-16 code unit positions (used by Document.selectRange)
// ============================================================

// ============================================================
// LIVE TEST MARKERS - DO NOT MODIFY THIS SECTION
// ============================================================
// These markers test byte↔UTF-16 conversion against real Document API.
// Each unicode char increases cumulative drift:
//   → (3 bytes, 1 UTF-16 unit) adds +2 to drift
//   한 (3 bytes, 1 UTF-16 unit) adds +2 to drift
//   🎹 (4 bytes, 2 UTF-16 units) adds +2 to drift
//
// [AAA_BEFORE_UNICODE] <- baseline (drift from ↔ in header)
// Arrow: →
// [BBB_AFTER_ARROW] <- baseline + 2
// Korean: 한
// [CCC_AFTER_KOREAN] <- baseline + 4
// Emoji: 🎹
// [DDD_AFTER_EMOJI] <- baseline + 6
// ============================================================

// ==================== CONVERTER FUNCTIONS ====================

(
// Determine UTF-8 byte length from leading byte
// Returns: 1, 2, 3, or 4
~utf8ByteLength = {|leadingByte|
    var code = leadingByte.ascii;
    case
        { code < 0 } { // Negative means high bit set (>127)
            // Convert to unsigned: code + 256
            var unsigned = code + 256;
            case
                { unsigned < 194 } { 1 }  // Invalid or continuation byte, treat as 1
                { unsigned < 224 } { 2 }  // 110xxxxx = 2-byte
                { unsigned < 240 } { 3 }  // 1110xxxx = 3-byte
                { unsigned < 248 } { 4 }  // 11110xxx = 4-byte
                { 1 };  // Invalid, treat as 1
        }
        { code < 128 } { 1 }  // ASCII
        { 1 };  // Fallback
};

// Determine UTF-16 code unit count for a Unicode codepoint
// Codepoints >= 0x10000 require surrogate pairs (2 units)
// We infer this from UTF-8 byte length:
//   - 4-byte UTF-8 = codepoint >= 0x10000 = 2 UTF-16 units
//   - 1,2,3-byte UTF-8 = 1 UTF-16 unit
~utf16UnitCount = {|utf8ByteLen|
    if(utf8ByteLen == 4, { 2 }, { 1 });
};

// Convert byte position to UTF-16 position
// Iterates through string, counting UTF-8 bytes and UTF-16 units
~byteToUtf16 = {|text, bytePos|
    var byteIdx = 0;
    var utf16Idx = 0;
    var textSize = text.size;

    while { byteIdx < bytePos and: { byteIdx < textSize } } {
        var byteLen = ~utf8ByteLength.(text[byteIdx]);
        var utf16Len = ~utf16UnitCount.(byteLen);

        byteIdx = byteIdx + byteLen;
        utf16Idx = utf16Idx + utf16Len;
    };

    utf16Idx;
};

// Convert UTF-16 position to byte position
// Iterates through string, counting UTF-16 units until target reached
~utf16ToByte = {|text, utf16Pos|
    var byteIdx = 0;
    var utf16Idx = 0;
    var textSize = text.size;

    while { utf16Idx < utf16Pos and: { byteIdx < textSize } } {
        var byteLen = ~utf8ByteLength.(text[byteIdx]);
        var utf16Len = ~utf16UnitCount.(byteLen);

        byteIdx = byteIdx + byteLen;
        utf16Idx = utf16Idx + utf16Len;
    };

    byteIdx;
};

"Converter functions loaded.".postln;
)

// ==================== TEST 0.9a: ASCII-only ====================
(
var text = "Hello World!";
var testCases = [[0, 0], [1, 1], [5, 5], [11, 11], [12, 12]];
var allPass = true;

"".postln;
"=== TEST 0.9a: ASCII-only ===".postln;
"text: '%'".format(text).postln;

testCases.do {|pair|
    var bytePos = pair[0];
    var expectedUtf16 = pair[1];
    var actualUtf16 = ~byteToUtf16.(text, bytePos);
    var pass = actualUtf16 == expectedUtf16;

    if(pass.not, {
        "  FAIL: byteToUtf16(%) expected % got %".format(bytePos, expectedUtf16, actualUtf16).postln;
        allPass = false;
    });
};

if(allPass, { "  PASS: All ASCII conversions correct".postln });
)

// ==================== TEST 0.9b: 2-byte UTF-8 ====================
(
var text = "café";  // é is 2 bytes
// Positions: c=0, a=1, f=2, é=3-4, end=5
// UTF-16:    c=0, a=1, f=2, é=3,   end=4
var testCases = [[0, 0], [1, 1], [2, 2], [3, 3], [5, 4]];
var allPass = true;

"".postln;
"=== TEST 0.9b: 2-byte UTF-8 (Latin) ===".postln;
"text: '%' (byte length: %)".format(text, text.size).postln;

testCases.do {|pair|
    var bytePos = pair[0];
    var expectedUtf16 = pair[1];
    var actualUtf16 = ~byteToUtf16.(text, bytePos);
    var pass = actualUtf16 == expectedUtf16;

    if(pass.not, {
        "  FAIL: byteToUtf16(%) expected % got %".format(bytePos, expectedUtf16, actualUtf16).postln;
        allPass = false;
    });
};

if(allPass, { "  PASS: All 2-byte conversions correct".postln });
)

// ==================== TEST 0.9c: 3-byte UTF-8 ====================
(
var text = "한글";  // Each Korean char is 3 bytes
// Positions: 한=0-2, 글=3-5, end=6
// UTF-16:    한=0,   글=1,   end=2
var testCases = [[0, 0], [3, 1], [6, 2]];
var allPass = true;

"".postln;
"=== TEST 0.9c: 3-byte UTF-8 (Korean) ===".postln;
"text: '%' (byte length: %)".format(text, text.size).postln;

testCases.do {|pair|
    var bytePos = pair[0];
    var expectedUtf16 = pair[1];
    var actualUtf16 = ~byteToUtf16.(text, bytePos);
    var pass = actualUtf16 == expectedUtf16;

    if(pass.not, {
        "  FAIL: byteToUtf16(%) expected % got %".format(bytePos, expectedUtf16, actualUtf16).postln;
        allPass = false;
    });
};

if(allPass, { "  PASS: All 3-byte conversions correct".postln });
)

// ==================== TEST 0.9d: 4-byte UTF-8 (emoji) ====================
(
var text = "🎹";  // Piano emoji: 4 bytes UTF-8, 2 UTF-16 units
// Positions: 🎹=0-3, end=4
// UTF-16:    🎹=0-1, end=2
var testCases = [[0, 0], [4, 2]];
var allPass = true;

"".postln;
"=== TEST 0.9d: 4-byte UTF-8 (emoji) ===".postln;
"text: '%' (byte length: %)".format(text, text.size).postln;

testCases.do {|pair|
    var bytePos = pair[0];
    var expectedUtf16 = pair[1];
    var actualUtf16 = ~byteToUtf16.(text, bytePos);
    var pass = actualUtf16 == expectedUtf16;

    if(pass.not, {
        "  FAIL: byteToUtf16(%) expected % got %".format(bytePos, expectedUtf16, actualUtf16).postln;
        allPass = false;
    });
};

if(allPass, { "  PASS: All 4-byte conversions correct".postln });
)

// ==================== TEST 0.9e: Mixed content ====================
(
var text = "a한b글c";  // Mixed ASCII and Korean
// a=0(1 byte), 한=1-3(3 bytes), b=4(1), 글=5-7(3), c=8(1) = 9 bytes
// UTF-16: a=0, 한=1, b=2, 글=3, c=4 = 5 units
var testCases = [[0, 0], [1, 1], [4, 2], [5, 3], [8, 4], [9, 5]];
var allPass = true;

"".postln;
"=== TEST 0.9e: Mixed content ===".postln;
"text: '%' (byte length: %)".format(text, text.size).postln;

testCases.do {|pair|
    var bytePos = pair[0];
    var expectedUtf16 = pair[1];
    var actualUtf16 = ~byteToUtf16.(text, bytePos);
    var pass = actualUtf16 == expectedUtf16;

    if(pass.not, {
        "  FAIL: byteToUtf16(%) expected % got %".format(bytePos, expectedUtf16, actualUtf16).postln;
        allPass = false;
    });
};

if(allPass, { "  PASS: All mixed conversions correct".postln });
)

// ==================== TEST 0.9f: Round-trip ====================
(
var text = "Hello→한글🎹World";
var byteLen = text.size;
var allPass = true;
var testedPositions = 0;

"".postln;
"=== TEST 0.9f: Round-trip verification ===".postln;
"text: '%' (byte length: %)".format(text, byteLen).postln;

// Test round-trip for all valid byte positions (character starts only)
// We find character starts by iterating properly
{
    var byteIdx = 0;
    while { byteIdx <= byteLen } {
        var utf16Pos = ~byteToUtf16.(text, byteIdx);
        var roundTrip = ~utf16ToByte.(text, utf16Pos);

        if(roundTrip != byteIdx, {
            "  FAIL: byte % -> utf16 % -> byte % (expected %)".format(
                byteIdx, utf16Pos, roundTrip, byteIdx
            ).postln;
            allPass = false;
        });
        testedPositions = testedPositions + 1;

        // Move to next character
        if(byteIdx < byteLen, {
            byteIdx = byteIdx + ~utf8ByteLength.(text[byteIdx]);
        }, {
            byteIdx = byteIdx + 1;  // Exit loop
        });
    };
}.value;

if(allPass, {
    "  PASS: All % round-trips correct".format(testedPositions).postln;
});
)

// ==================== TEST 0.9g: Python-generated vectors ====================
(
// Auto-generated test vectors from m09-test-vectors.py
// Format: [string, [[bytePos, utf16Pos], ...]]
var testVectors = [
    // ascii_only: byte_len=12, utf16_len=12
    ["Hello World!", [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6], [7, 7], [8, 8], [9, 9], [10, 10], [11, 11], [12, 12]]],
    // latin_2byte: byte_len=5, utf16_len=4
    ["café", [[0, 0], [1, 1], [2, 2], [3, 3], [5, 4]]],
    // greek: byte_len=8, utf16_len=4
    ["αβγδ", [[0, 0], [2, 1], [4, 2], [6, 3], [8, 4]]],
    // cyrillic: byte_len=12, utf16_len=6
    ["Привет", [[0, 0], [2, 1], [4, 2], [6, 3], [8, 4], [10, 5], [12, 6]]],
    // korean: byte_len=6, utf16_len=2
    ["한글", [[0, 0], [3, 1], [6, 2]]],
    // japanese: byte_len=9, utf16_len=3
    ["日本語", [[0, 0], [3, 1], [6, 2], [9, 3]]],
    // arrows: byte_len=12, utf16_len=4
    ["→←↑↓", [[0, 0], [3, 1], [6, 2], [9, 3], [12, 4]]],
    // math_symbols: byte_len=12, utf16_len=4
    ["∑∏∫∂", [[0, 0], [3, 1], [6, 2], [9, 3], [12, 4]]],
    // single_emoji: byte_len=4, utf16_len=2
    ["🎹", [[0, 0], [4, 2]]],
    // multiple_emoji: byte_len=12, utf16_len=6
    ["🎹🎸🎺", [[0, 0], [4, 2], [8, 4], [12, 6]]],
    // family_emoji: byte_len=25, utf16_len=11
    ["👨‍👩‍👧‍👦", [[0, 0], [4, 2], [7, 3], [11, 5], [14, 6], [18, 8], [21, 9], [25, 11]]],
    // mixed_ascii_arrow: byte_len=13, utf16_len=11
    ["Hello→World", [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [8, 6], [9, 7], [10, 8], [11, 9], [12, 10], [13, 11]]],
    // mixed_ascii_korean: byte_len=9, utf16_len=5
    ["a한b글c", [[0, 0], [1, 1], [4, 2], [5, 3], [8, 4], [9, 5]]],
    // mixed_ascii_emoji: byte_len=11, utf16_len=9
    ["test🎹end", [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [8, 6], [9, 7], [10, 8], [11, 9]]],
    // mixed_all: byte_len=22, utf16_len=13
    ["café→한글🎹done", [[0, 0], [1, 1], [2, 2], [3, 3], [5, 4], [8, 5], [11, 6], [14, 7], [18, 9], [19, 10], [20, 11], [21, 12], [22, 13]]],
    // empty: byte_len=0, utf16_len=0
    ["", [[0, 0]]],
    // single_ascii: byte_len=1, utf16_len=1
    ["a", [[0, 0], [1, 1]]],
    // single_2byte: byte_len=2, utf16_len=1
    ["é", [[0, 0], [2, 1]]],
    // single_3byte: byte_len=3, utf16_len=1
    ["한", [[0, 0], [3, 1]]],
    // single_4byte: byte_len=4, utf16_len=2
    ["🎹", [[0, 0], [4, 2]]],
    // boundary_test: byte_len=22, utf16_len=16
    ["abc→def한ghi🎹jkl", [[0, 0], [1, 1], [2, 2], [3, 3], [6, 4], [7, 5], [8, 6], [9, 7], [12, 8], [13, 9], [14, 10], [15, 11], [19, 13], [20, 14], [21, 15], [22, 16]]],
];

var totalTests = 0;
var passedTests = 0;
var failedVectors = List.new;

"".postln;
"=== TEST 0.9g: Python-generated vectors ===".postln;
"Testing % strings...".format(testVectors.size).postln;

testVectors.do {|vector, vectorIdx|
    var text = vector[0];
    var positions = vector[1];
    var vectorPass = true;

    positions.do {|pair|
        var bytePos = pair[0];
        var expectedUtf16 = pair[1];
        var actualUtf16 = ~byteToUtf16.(text, bytePos);

        totalTests = totalTests + 1;

        if(actualUtf16 != expectedUtf16, {
            if(vectorPass, {
                failedVectors.add(vectorIdx);
            });
            vectorPass = false;
            "  FAIL [%]: '%' byte % -> utf16 expected % got %".format(
                vectorIdx, text[0..10], bytePos, expectedUtf16, actualUtf16
            ).postln;
        }, {
            passedTests = passedTests + 1;
        });
    };
};

"".postln;
"Results: %/% tests passed".format(passedTests, totalTests).postln;
if(failedVectors.size > 0, {
    "Failed vectors: %".format(failedVectors).postln;
}, {
    "ALL TESTS PASSED!".postln;
});
)

// ==================== TEST 0.9h: Reverse direction ====================
(
// Test utf16ToByte with the same vectors
var testVectors = [
    ["Hello World!", [[0, 0], [1, 1], [5, 5], [12, 12]]],
    ["café", [[0, 0], [3, 3], [4, 5]]],  // utf16=4 should give byte=5
    ["한글", [[0, 0], [1, 3], [2, 6]]],
    ["🎹", [[0, 0], [2, 4]]],
    ["a한b글c", [[0, 0], [1, 1], [2, 4], [3, 5], [4, 8], [5, 9]]],
    ["Hello→World", [[0, 0], [5, 5], [6, 8], [11, 13]]],
];

var totalTests = 0;
var passedTests = 0;

"".postln;
"=== TEST 0.9h: utf16ToByte reverse direction ===".postln;

testVectors.do {|vector|
    var text = vector[0];
    var positions = vector[1];

    positions.do {|pair|
        var utf16Pos = pair[0];
        var expectedByte = pair[1];
        var actualByte = ~utf16ToByte.(text, utf16Pos);

        totalTests = totalTests + 1;

        if(actualByte != expectedByte, {
            "  FAIL: '%' utf16 % -> byte expected % got %".format(
                text[0..10], utf16Pos, expectedByte, actualByte
            ).postln;
        }, {
            passedTests = passedTests + 1;
        });
    };
};

"".postln;
"Results: %/% tests passed".format(passedTests, totalTests).postln;
if(passedTests == totalTests, { "ALL TESTS PASSED!".postln });
)

// ==================== LIVE VERIFICATION ====================
// Test converter against actual Document.selectRange behavior
// Uses the LIVE TEST MARKERS at the top of this file
(
var doc = Document.current;
var text = doc.string;
var markers = [
    // [marker_name, drift_increment_from_previous]
    // Total drift = baseline (from ↔ in header) + increments
    // Increments: → adds +2, 한 adds +2, 🎹 adds +2
    ["AAA_BEFORE_UNICODE", 0],  // baseline
    ["BBB_AFTER_ARROW", 2],     // +2 from →
    ["CCC_AFTER_KOREAN", 4],    // +4 from → + 한
    ["DDD_AFTER_EMOJI", 6],     // +6 from → + 한 + 🎹
];
var baselineDrift;  // will be set from AAA
var allPass = true;

"".postln;
"=== LIVE VERIFICATION ===".postln;
"Testing converter against Document.selectRange using markers in this file.".postln;
"".postln;

markers.do {|markerInfo, idx|
    var markerName = markerInfo[0];
    var expectedIncrement = markerInfo[1];
    var bytePos, utf16Pos, actualDrift, expectedDrift;
    var selected, foundAt;

    // Find marker in byte-indexed string
    bytePos = text.find(markerName);
    if(bytePos.isNil, {
        "  FAIL: Marker '%' not found in document!".format(markerName).postln;
        allPass = false;
    }, {
        // Convert byte position to UTF-16
        utf16Pos = ~byteToUtf16.(text, bytePos);
        actualDrift = bytePos - utf16Pos;

        // First marker sets baseline
        if(idx == 0, {
            baselineDrift = actualDrift;
            "  Baseline drift from earlier unicode: %".format(baselineDrift).postln;
        });

        // Verify drift increment matches expected
        expectedDrift = baselineDrift + expectedIncrement;
        if(actualDrift != expectedDrift, {
            "  WARN: % drift is % (expected % = baseline % + increment %)".format(
                markerName, actualDrift, expectedDrift, baselineDrift, expectedIncrement
            ).postln;
        });

        // THE REAL TEST: Use selectRange with converted position
        // and verify it selects the marker
        doc.selectRange(utf16Pos, markerName.size);
        selected = doc.selectedString;

        if(selected == markerName, {
            "  PASS: % (byte %, utf16 %, drift %)".format(
                markerName, bytePos, utf16Pos, actualDrift
            ).postln;
        }, {
            // Where did we actually select?
            foundAt = text.find(selected);
            "  FAIL: %".format(markerName).postln;
            "        Expected to select '%'".format(markerName).postln;
            "        Actually selected '%' (at byte %)".format(selected, foundAt).postln;
            "        bytePos=%, utf16Pos=%, drift=%".format(bytePos, utf16Pos, actualDrift).postln;
            allPass = false;
        });
    });
};

"".postln;
if(allPass, {
    "ALL LIVE TESTS PASSED! Converter is working correctly.".postln;
}, {
    "SOME TESTS FAILED - converter needs debugging.".postln;
});
)

// ==================== LIVE VERIFICATION (REVERSE) ====================
// Test utf16ToByte: start with selectRange position, convert to byte position
(
var doc = Document.current;
var text = doc.string;
var testUtf16Positions = [100, 200, 300, 400, 500];
var allPass = true;

"".postln;
"=== LIVE VERIFICATION (REVERSE) ===".postln;
"Test utf16ToByte: given UTF-16 pos, find correct byte position.".postln;
"".postln;

testUtf16Positions.do {|utf16Pos|
    var bytePos, selected, textAtBytePos;

    // Select 10 chars at this UTF-16 position
    doc.selectRange(utf16Pos, 10);
    selected = doc.selectedString;

    // Use our converter to get expected byte position
    bytePos = ~utf16ToByte.(text, utf16Pos);

    // THE REAL TEST: Does text at converted byte position match what was selected?
    // This is the correct test - we don't care about text.find() duplicates
    textAtBytePos = text[bytePos..bytePos + selected.size - 1];

    if(textAtBytePos == selected, {
        "  PASS: utf16 % -> byte % (text matches: '%')".format(
            utf16Pos, bytePos, selected.replace("\n", "\\n")[0..15]
        ).postln;
    }, {
        "  FAIL: utf16 % -> byte %".format(utf16Pos, bytePos).postln;
        "        selectRange got: '%'".format(selected.replace("\n", "\\n")).postln;
        "        text[byte] has:  '%'".format(textAtBytePos.replace("\n", "\\n")).postln;
        allPass = false;
    });
};

"".postln;
if(allPass, {
    "ALL REVERSE TESTS PASSED!".postln;
}, {
    "SOME REVERSE TESTS FAILED.".postln;
});
)

// ==================== SUMMARY ====================
(
"".postln;
"=== MILESTONE 0.9 SUMMARY ===".postln;
"".postln;
"Test checklist:".postln;
"  [ ] 0.9a - ASCII-only conversion".postln;
"  [ ] 0.9b - 2-byte UTF-8 (Latin)".postln;
"  [ ] 0.9c - 3-byte UTF-8 (Korean)".postln;
"  [ ] 0.9d - 4-byte UTF-8 (emoji)".postln;
"  [ ] 0.9e - Mixed content".postln;
"  [ ] 0.9f - Round-trip verification".postln;
"  [ ] 0.9g - Python-generated vectors (126 tests)".postln;
"  [ ] 0.9h - Reverse direction (utf16->byte)".postln;
"  [ ] LIVE VERIFICATION - Against real Document.selectRange".postln;
"  [ ] LIVE VERIFICATION (REVERSE) - utf16ToByte accuracy".postln;
"".postln;
"ALL tests must pass before proceeding to Milestone 1.".postln;
"".postln;
"Converter functions:".postln;
"  ~byteToUtf16.(text, bytePos) -> utf16Pos  // for selectRange".postln;
"  ~utf16ToByte.(text, utf16Pos) -> bytePos  // for string indexing".postln;
)
