// ============================================================
// EXPERIMENT: Determine selectRange coordinate system
// ============================================================
// This experiment tests whether selectRange uses:
//   A) UTF-16 code units for both position and length
//   B) Codepoints for both position and length
//   C) UTF-16 for position, codepoints for length (mixed)
//
// Test content: "ABC🎹🎹XYZ"
//   Bytes:     A(1) B(1) C(1) 🎹(4) 🎹(4) X(1) Y(1) Z(1) = 14 bytes
//   UTF-16:    A(1) B(1) C(1) 🎹(2) 🎹(2) X(1) Y(1) Z(1) = 10 units
//   Codepoints: A(1) B(1) C(1) 🎹(1) 🎹(1) X(1) Y(1) Z(1) = 8 chars
//
// To select ONLY the two emojis:
//   If UTF-16:    selectRange(3, 4)  -- start at unit 3, length 4 units
//   If codepoints: selectRange(3, 2) -- start at char 3, length 2 chars
// ============================================================

// ============================================================
// SETUP: Create temp file with test content
// ============================================================
(
var tempPath = PathName.tmp +/+ "selectRange_experiment.txt";
var content = "ABC🎹🎹XYZ\n";

// Write test file
File.use(tempPath, "w", {|f| f.write(content) });
~expTempPath = tempPath;
~expDoc = nil;

"Created temp file: %".format(tempPath).postln;
"Content: 'ABC🎹🎹XYZ'".postln;
"".postln;
"Coordinate reference:".postln;
"  Bytes:      A=0, B=1, C=2, 🎹=3-6, 🎹=7-10, X=11, Y=12, Z=13".postln;
"  UTF-16:     A=0, B=1, C=2, 🎹=3-4, 🎹=5-6, X=7, Y=8, Z=9".postln;
"  Codepoints: A=0, B=1, C=2, 🎹=3, 🎹=4, X=5, Y=6, Z=7".postln;
)

// ============================================================
// OPEN DOCUMENT
// ============================================================
(
~expDoc = Document.open(~expTempPath);
"Document opened. Run experiments below.".postln;
)

// ============================================================
// EXPERIMENT A: Test selectRange with UTF-16 interpretation
// ============================================================
// If selectRange uses UTF-16: selectRange(3, 4) should select 🎹🎹
(
"=== EXPERIMENT A: UTF-16 interpretation ===".postln;
"selectRange(3, 4) -- expecting to select '🎹🎹'".postln;

~expDoc.selectRange(3, 4);
"Selected: '%'".format(~expDoc.selectedString).postln;

if(~expDoc.selectedString == "🎹🎹") {
    "RESULT: UTF-16 interpretation is CORRECT for selectRange".postln;
} {
    "RESULT: UTF-16 interpretation is WRONG".postln;
    "Got '%' instead of '🎹🎹'".format(~expDoc.selectedString).postln;
};
)

// ============================================================
// EXPERIMENT B: Test selectRange with codepoint interpretation
// ============================================================
// If selectRange uses codepoints: selectRange(3, 2) should select 🎹🎹
(
"".postln;
"=== EXPERIMENT B: Codepoint interpretation ===".postln;
"selectRange(3, 2) -- expecting to select '🎹🎹'".postln;

~expDoc.selectRange(3, 2);
"Selected: '%'".format(~expDoc.selectedString).postln;

if(~expDoc.selectedString == "🎹🎹") {
    "RESULT: Codepoint interpretation is CORRECT for selectRange".postln;
} {
    "RESULT: Codepoint interpretation is WRONG".postln;
    "Got '%' instead of '🎹🎹'".format(~expDoc.selectedString).postln;
};
)

// ============================================================
// EXPERIMENT C: What does selectRange(3, 4) actually select?
// ============================================================
(
"".postln;
"=== EXPERIMENT C: Actual behavior analysis ===".postln;

~expDoc.selectRange(3, 4);
var selected = ~expDoc.selectedString;
var selectedBytes = selected.size;

"selectRange(3, 4) selected:".postln;
"  String: '%'".format(selected).postln;
"  Byte length: %".format(selectedBytes).postln;

// Analyze what was selected
case
    { selected == "🎹🎹" } {
        "CONCLUSION: selectRange uses UTF-16 code units".postln;
        "  (4 UTF-16 units = 2 emojis)".postln;
    }
    { selected == "🎹🎹XY" } {
        "CONCLUSION: selectRange uses CODEPOINTS for length".postln;
        "  (position 3 correct, but length 4 = 4 codepoints = 2 emojis + 2 chars)".postln;
    }
    { selected.size == 4 } {
        "CONCLUSION: selectRange uses BYTES".postln;
        "  (4 bytes from position 3)".postln;
    }
    {
        "CONCLUSION: Unknown behavior".postln;
        "  Need to analyze further".postln;
    };
)

// ============================================================
// EXPERIMENT D: Position test - select X (after emojis)
// ============================================================
(
"".postln;
"=== EXPERIMENT D: Position after emoji ===".postln;
"Trying to select 'X' (1 char after the emojis)".postln;
"".postln;

// If UTF-16: X is at position 7, selectRange(7, 1)
"Testing UTF-16 position: selectRange(7, 1)".postln;
~expDoc.selectRange(7, 1);
"  Selected: '%'".format(~expDoc.selectedString).postln;

// If codepoints: X is at position 5, selectRange(5, 1)
"Testing codepoint position: selectRange(5, 1)".postln;
~expDoc.selectRange(5, 1);
"  Selected: '%'".format(~expDoc.selectedString).postln;
)

// ============================================================
// EXPERIMENT E: Direct test of the M2 scenario
// ============================================================
(
"".postln;
"=== EXPERIMENT E: M2 scenario simulation ===".postln;
"Content: 'ABC🎹🎹XYZ' -- want to replace 🎹🎹 with 'NEW'".postln;
"".postln;

var text = ~expDoc.string;
var targetStart, targetEnd;

// Find the emojis using byte indexing (like M2 does)
// "ABC" = 3 bytes, emoji content starts at byte 3
targetStart = 3;  // byte position after "ABC"

// Find end by scanning for next ASCII char
targetEnd = targetStart;
while { targetEnd < text.size and: { text[targetEnd].ascii < 0 or: { text[targetEnd].ascii > 127 } } } {
    targetEnd = targetEnd + 1;
};

"Byte range of emojis: %..% (% bytes)".format(targetStart, targetEnd, targetEnd - targetStart).postln;

// Now test different conversion strategies:

// Strategy 1: UTF-16 conversion (original M0.9)
"".postln;
"Strategy 1: UTF-16 conversion".postln;
{
    var utf16Start = 0, utf16End = 0;
    var byteIdx = 0;
    // Convert targetStart
    while { byteIdx < targetStart } {
        var b = text[byteIdx].ascii;
        var byteLen = case
            { b >= 0 and: { b < 128 } } { 1 }
            { (b + 256) < 224 } { 2 }
            { (b + 256) < 240 } { 3 }
            { 4 };
        var utf16Units = if(byteLen == 4, { 2 }, { 1 });
        byteIdx = byteIdx + byteLen;
        utf16Start = utf16Start + utf16Units;
    };
    // Convert targetEnd
    byteIdx = 0;
    while { byteIdx < targetEnd } {
        var b = text[byteIdx].ascii;
        var byteLen = case
            { b >= 0 and: { b < 128 } } { 1 }
            { (b + 256) < 224 } { 2 }
            { (b + 256) < 240 } { 3 }
            { 4 };
        var utf16Units = if(byteLen == 4, { 2 }, { 1 });
        byteIdx = byteIdx + byteLen;
        utf16End = utf16End + utf16Units;
    };
    "  UTF-16 range: selectRange(%, %)".format(utf16Start, utf16End - utf16Start).postln;
    ~expDoc.selectRange(utf16Start, utf16End - utf16Start);
    "  Selected: '%'".format(~expDoc.selectedString).postln;
}.value;

// Strategy 2: Codepoint conversion (my fix)
"".postln;
"Strategy 2: Codepoint conversion".postln;
{
    var cpStart = 0, cpEnd = 0;
    var byteIdx = 0;
    // Convert targetStart
    while { byteIdx < targetStart } {
        var b = text[byteIdx].ascii;
        var byteLen = case
            { b >= 0 and: { b < 128 } } { 1 }
            { (b + 256) < 224 } { 2 }
            { (b + 256) < 240 } { 3 }
            { 4 };
        byteIdx = byteIdx + byteLen;
        cpStart = cpStart + 1;  // Always 1 codepoint
    };
    // Convert targetEnd
    byteIdx = 0;
    while { byteIdx < targetEnd } {
        var b = text[byteIdx].ascii;
        var byteLen = case
            { b >= 0 and: { b < 128 } } { 1 }
            { (b + 256) < 224 } { 2 }
            { (b + 256) < 240 } { 3 }
            { 4 };
        byteIdx = byteIdx + byteLen;
        cpEnd = cpEnd + 1;
    };
    "  Codepoint range: selectRange(%, %)".format(cpStart, cpEnd - cpStart).postln;
    ~expDoc.selectRange(cpStart, cpEnd - cpStart);
    "  Selected: '%'".format(~expDoc.selectedString).postln;
}.value;
)

// ============================================================
// CLEANUP
// ============================================================
(
"".postln;
"=== CLEANUP ===".postln;
if(~expDoc.notNil) { ~expDoc.close };
if(~expTempPath.notNil) { File.delete(~expTempPath) };
"Done.".postln;
)
