// ============================================================
// EXPERIMENT: selectRange LENGTH with Non-BMP Characters
// ============================================================
// This experiment tests what M0.9 missed: the LENGTH parameter
// of selectRange when dealing with surrogate pairs (emoji, etc.)
//
// HYPOTHESIS: selectRange(start, len) interprets len as:
//   - Codepoint count (each emoji = 1), NOT
//   - UTF-16 unit count (each emoji = 2)
//
// Run each block sequentially and observe results.
// ============================================================

// ============================================================
// SETUP: Load module and define test content
// ============================================================
(
var thisDir = PathName(thisProcess.nowExecutingPath).pathOnly;
(thisDir +/+ "wildcard-visual-m09-module.scd").load;

// Store test content globally
~testContent = "PREFIX🎹🎹SUFFIX";
// Breakdown:
//   PREFIX = 6 ASCII chars = 6 bytes = 6 codepoints
//   🎹🎹   = 2 emoji = 8 bytes = 2 codepoints (= 4 UTF-16 units if we were wrong)
//   SUFFIX = 6 ASCII chars = 6 bytes = 6 codepoints
// Total: 20 bytes, 14 codepoints

"Test content: '%'".format(~testContent).postln;
"Byte length: %".format(~testContent.size).postln;
)

// ============================================================
// EXPERIMENT 1: What position does byte 6 convert to?
// ============================================================
// Byte 6 = start of first emoji
// If codepoints: position 6
// If UTF-16 units: position 6 (same, no emoji before)
(
var text = ~testContent;
var bytePos = 6;  // Start of 🎹🎹
var result = ~byteToUtf16.(text, bytePos);
"Byte % -> selectRange position: %".format(bytePos, result).postln;
"Expected (codepoint): 6".postln;
"Expected (utf16): 6".postln;
// Both should be 6 since no emoji before this position
)

// ============================================================
// EXPERIMENT 2: What position does byte 14 convert to?
// ============================================================
// Byte 14 = start of SUFFIX (after both emoji)
// If codepoints: position 8 (6 + 2 emoji)
// If UTF-16 units: position 10 (6 + 2*2 surrogate pairs)
(
var text = ~testContent;
var bytePos = 14;  // Start of SUFFIX
var result = ~byteToUtf16.(text, bytePos);
"Byte % -> selectRange position: %".format(bytePos, result).postln;
"Expected (codepoint): 8".postln;
"Expected (utf16): 10".postln;
// OLD CODE would return 10 (wrong for codepoint API)
// FIXED CODE should return 8 (correct for codepoint API)
)

// ============================================================
// EXPERIMENT 3: What is the LENGTH of the emoji section?
// ============================================================
// Emoji section: 🎹🎹 = bytes 6-13 (8 bytes)
// If codepoints: length 2
// If UTF-16 units: length 4
(
var text = ~testContent;
var startByte = 6;
var endByte = 14;  // Exclusive end
var startPos = ~byteToUtf16.(text, startByte);
var endPos = ~byteToUtf16.(text, endByte);
var length = endPos - startPos;
"Emoji section byte range: %..%".format(startByte, endByte).postln;
"selectRange length: % - % = %".format(endPos, startPos, length).postln;
"Expected (codepoint): 8 - 6 = 2".postln;
"Expected (utf16): 10 - 6 = 4".postln;
// OLD CODE would give length 4 (selecting too much)
// FIXED CODE should give length 2 (correct)
)

// ============================================================
// EXPERIMENT 4: LIVE TEST - Create temp file and verify
// ============================================================
// This creates a temporary file with emoji, opens it,
// and tests that selectRange with our calculated length
// actually selects ONLY the emoji content.
(
var tempPath = PathName.tmp +/+ "selectRange_emoji_test.txt";
var content = "START🎹🎹END\n";
var doc, text, emojiStart, emojiEnd, selectStart, selectLen, selected;

// Write test file
File.use(tempPath, "w", {|f| f.write(content) });
"Created temp file: %".format(tempPath).postln;

// Open it
doc = Document.open(tempPath);
0.3.wait;

text = doc.string;
"Doc content: '%'".format(text.replace("\n", "\\n")).postln;

// Find emoji section
// START = 5 bytes, emoji section starts at byte 5
emojiStart = 5;  // Byte position after "START"
emojiEnd = 13;   // Byte position of "END" (5 + 8 bytes for 2 emoji)

selectStart = ~byteToUtf16.(text, emojiStart);
selectLen = ~byteToUtf16.(text, emojiEnd) - selectStart;

"Byte range: %..% (exclusive)".format(emojiStart, emojiEnd).postln;
"selectRange(%,  %)".format(selectStart, selectLen).postln;

doc.selectRange(selectStart, selectLen);
selected = doc.selectedString;

"".postln;
"=== RESULT ===".postln;
"Selected: '%'".format(selected).postln;
"Expected: '🎹🎹'".postln;

if(selected == "🎹🎹") {
    "PASS: selectRange correctly selected only emoji".postln;
} {
    "FAIL: selectRange selected wrong content!".postln;
    "This means the LENGTH was interpreted as UTF-16 units, not codepoints.".postln;
};

// Cleanup
doc.close;
File.delete(tempPath);
}.fork(AppClock);
)

// ============================================================
// EXPERIMENT 5: REPLACEMENT TEST - The actual M2 bug case
// ============================================================
// This simulates what test-runner.scd does: find content, replace it.
(
var tempPath = PathName.tmp +/+ "selectRange_replace_test.txt";
var original = "~emoji.(🎹🎹);\n~next.(....);\n";
var doc, text, patternPos, contentStart, contentEnd, depth;
var selectStart, selectLen, expected, actual;

// Write test file
File.use(tempPath, "w", {|f| f.write(original) });
"Created temp file: %".format(tempPath).postln;

// Open it
doc = Document.open(tempPath);
0.3.wait;

text = doc.string;
"Original: '%'".format(text.replace("\n", "\\n")).postln;

// Find ~emoji.( pattern
patternPos = text.find("~emoji.(");
contentStart = patternPos + "~emoji.(".size;

// Find closing paren (same logic as test-runner.scd)
contentEnd = contentStart;
depth = 1;
while { (depth > 0) && (contentEnd < text.size) } {
    case
        { text[contentEnd] == $( } { depth = depth + 1 }
        { text[contentEnd] == $) } { depth = depth - 1 };
    if (depth > 0) { contentEnd = contentEnd + 1 };
};

"Content byte range: %..% (exclusive)".format(contentStart, contentEnd).postln;
"Content bytes: '%'".format(text[contentStart..contentEnd-1]).postln;

// Convert to selectRange coordinates
selectStart = ~byteToUtf16.(text, contentStart);
selectLen = ~byteToUtf16.(text, contentEnd) - selectStart;

"selectRange(%, %)".format(selectStart, selectLen).postln;

// Replace
doc.selectRange(selectStart, selectLen);
"About to replace '%' with '0.3'".format(doc.selectedString).postln;
doc.selectedString_("0.3");

0.1.wait;

// Verify
expected = "~emoji.(0.3);";
actual = doc.string;

"".postln;
"=== RESULT ===".postln;
"After replacement: '%'".format(actual.replace("\n", "\\n")).postln;

if(actual.find(expected).notNil) {
    "PASS: Replacement preserved closing );".postln;
} {
    "FAIL: Closing ); was eaten!".postln;
    "Looking for: '%'".format(expected).postln;
};

// Cleanup
doc.close;
File.delete(tempPath);
}.fork(AppClock);
)

// ============================================================
// SUMMARY
// ============================================================
(
"".postln;
"=== EXPERIMENT SUMMARY ===".postln;
"".postln;
"The M0.9 tests verified POSITION conversion but not LENGTH semantics.".postln;
"They used ASCII markers, so length in bytes = UTF-16 = codepoints.".postln;
"".postln;
"The M2 bug revealed: selectRange LENGTH uses codepoint count,".postln;
"not UTF-16 unit count. For emoji (surrogate pairs), this matters:".postln;
"  - 🎹 = 4 bytes = 2 UTF-16 units = 1 codepoint".postln;
"".postln;
"FIX: Changed ~charCountForSelectRange to always return 1,".postln;
"making ~byteToUtf16 count codepoints instead of UTF-16 units.".postln;
)
