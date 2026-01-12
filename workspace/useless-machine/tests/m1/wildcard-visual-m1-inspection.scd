// ============================================================
// MILESTONE 1: READ-ONLY DOCUMENT INSPECTION
// ============================================================
// Goal: Find and parse the control panel WITHOUT modifying anything.
//
// Tests 1.1-1.3: Use File.readAllString (no Document dependency)
// Test 1.4: Opens test target in IDE to verify selectRange
// ============================================================

// ==================== LOAD DEPENDENCIES ====================
(
var thisDir = PathName(thisProcess.nowExecutingPath).pathOnly;
var m09Path = thisDir +/+ "wildcard-visual-m09-module.scd";
var targetPath = thisDir +/+ "wildcard-visual-test-target.scd";

// Load converter module
if(File.exists(m09Path), {
    m09Path.load;
}, {
    "[M1] ERROR: Could not find module at: %".format(m09Path).postln;
});

// Store paths for other tests
~m1ThisDir = thisDir;
~m1TargetPath = targetPath;

// Verify
if(~byteToUtf16.notNil and: File.exists(targetPath), {
    "[M1] Ready. Module loaded, target file exists.".postln;
    "[M1] Target: %".format(targetPath).postln;
}, {
    "[M1] ERROR: Missing dependencies.".postln;
    if(~byteToUtf16.isNil, { "  - Converter not loaded".postln });
    if(File.exists(targetPath).not, { "  - Target file not found".postln });
});
)

// ==================== TEST 1.1: Find known string pattern ====================
(
var text = File.readAllString(~m1TargetPath);
var pattern = "~rev.(";
var bytePos = text.find(pattern);

"".postln;
"=== TEST 1.1: Find known string pattern ===".postln;
"Source: File.readAllString (not Document.current)".postln;

if(bytePos.isNil, {
    "FAIL: Could not find '%' in target file".format(pattern).postln;
}, {
    "PASS: Found '%' at byte position %".format(pattern, bytePos).postln;
    "  context: '%'".format(text[bytePos..(bytePos+30).min(text.size-1)]).postln;
});
)

// ==================== TEST 1.2: Find dot string within controller ====================
(
var text = File.readAllString(~m1TargetPath);
var controllerStart = text.find("~rev.(");
var searchRegion, quoteStart, quoteEnd, dots;
var absByteStart, absByteEnd;

"".postln;
"=== TEST 1.2: Find dot string within controller ===".postln;

if(controllerStart.isNil, {
    "FAIL: Controller '~rev.(' not found".postln;
}, {
    searchRegion = text[controllerStart..(controllerStart+100).min(text.size-1)];
    quoteStart = searchRegion.find("\"");

    if(quoteStart.notNil, {
        quoteEnd = searchRegion.find("\"", false, quoteStart + 1);
    });

    if(quoteStart.isNil or: quoteEnd.isNil, {
        "FAIL: Could not find quoted string".postln;
        "  searchRegion: '%'".format(searchRegion[0..50]).postln;
    }, {
        absByteStart = controllerStart + quoteStart + 1;
        absByteEnd = controllerStart + quoteEnd;
        dots = text[absByteStart..absByteEnd-1];

        if(dots == ".........", {
            "PASS: Found dots = '%' (% chars)".format(dots, dots.size).postln;
        }, {
            "WARN: Found dots = '%' (expected '.........')".format(dots).postln;
        });
        "  byte positions: % to %".format(absByteStart, absByteEnd-1).postln;
    });
});
)

// ==================== TEST 1.3: Parse all controllers into registry ====================
(
var text = File.readAllString(~m1TargetPath);
var controllerNames = [\rev, \speed, \jitter, \silence, \fade, \stut, \grain];
var registry = IdentityDictionary.new;
var expectedDots = (
    rev: ".........",
    speed: ".....",
    jitter: "....",
    silence: ".......",
    fade: "..",
    stut: "......",
    grain: "...",
);
var allPass = true;

"".postln;
"=== TEST 1.3: Parse all controllers into registry ===".postln;

controllerNames.do {|name|
    var pattern = "~" ++ name ++ ".(";
    var pos = text.find(pattern);
    var searchRegion, q1, q2, dots, absByteStart, absByteEnd;
    var expected = expectedDots[name];

    if(pos.notNil, {
        searchRegion = text[pos..(pos+150).min(text.size-1)];
        q1 = searchRegion.find("\"");
        if(q1.notNil, { q2 = searchRegion.find("\"", false, q1 + 1) });

        if(q1.notNil and: q2.notNil, {
            absByteStart = pos + q1 + 1;
            absByteEnd = pos + q2;
            dots = text[absByteStart..absByteEnd-1];

            registry[name] = (
                pattern: pattern,
                byteStart: absByteStart,
                byteEnd: absByteEnd,
                currentDots: dots,
                dotCount: dots.size,
            );

            if(dots == expected, {
                "  PASS %: byte %..%, dots='%'".format(name, absByteStart, absByteEnd-1, dots).postln;
            }, {
                "  FAIL %: got '%', expected '%'".format(name, dots, expected).postln;
                allPass = false;
            });
        }, {
            "  FAIL %: found pattern but no quoted string".format(name).postln;
            allPass = false;
        });
    }, {
        "  FAIL %: pattern not found".format(name).postln;
        allPass = false;
    });
};

"".postln;
if(allPass, {
    "ALL 7 CONTROLLERS PARSED CORRECTLY".postln;
}, {
    "SOME CONTROLLERS FAILED".postln;
});
"Registry built with % entries".format(registry.size).postln;
~m1Registry = registry;
~m1Text = text;  // Save for test 1.4
)

// ==================== TEST 1.4: Verify positions with selectRange ====================
// This test OPENS the target file in the IDE to verify Document API works
// NOTE: Document.open is synchronous - no callback needed
(
var targetPath = ~m1TargetPath;
var registry = ~m1Registry;
var savedText = ~m1Text;
var doc, text, allPass = true;

"".postln;
"=== TEST 1.4: Verify positions with selectRange ===".postln;

if(registry.isNil or: { registry.size == 0 }, {
    "FAIL: No registry found. Run test 1.3 first.".postln;
}, {
    "Opening target file...".postln;
    doc = Document.open(targetPath);

    if(doc.isNil, {
        "FAIL: Document.open returned nil".postln;
    }, {
        text = doc.string;
        "Document opened. Verifying % controllers...".format(registry.size).postln;
        "".postln;

        // Verify text matches what we parsed
        if(text != savedText, {
            "WARN: Document text differs from File.readAllString!".postln;
            "  File size: %, Doc size: %".format(savedText.size, text.size).postln;
        });

        registry.keysValuesDo {|name, info|
            var byteStart = info.byteStart;
            var expectedDots = info.currentDots;
            var utf16Start, selected;

            utf16Start = ~byteToUtf16.(text, byteStart);
            doc.selectRange(utf16Start, expectedDots.size);
            selected = doc.selectedString;

            if(selected == expectedDots, {
                "  PASS %: selectRange(%, %) -> '%'".format(
                    name, utf16Start, expectedDots.size, selected
                ).postln;
            }, {
                "  FAIL %:".format(name).postln;
                "        Expected: '%'".format(expectedDots).postln;
                "        Selected: '%'".format(selected).postln;
                "        byteStart=%, utf16Start=%".format(byteStart, utf16Start).postln;
                allPass = false;
            });
        };

        "".postln;
        if(allPass, {
            "ALL POSITION VERIFICATIONS PASSED!".postln;
            "Byte->UTF-16 conversion verified against Document.selectRange.".postln;
        }, {
            "SOME VERIFICATIONS FAILED - check converter.".postln;
        });
    });
});
)

// ==================== HELPER: Reusable scanner function ====================
(
~scanControllersInText = {|text, controllerNames|
    var registry = IdentityDictionary.new;

    controllerNames.do {|name|
        var pattern = "~" ++ name ++ ".(";
        var pos = text.find(pattern);
        var searchRegion, q1, q2, dots, absByteStart, absByteEnd;

        if(pos.notNil, {
            searchRegion = text[pos..(pos+150).min(text.size-1)];
            q1 = searchRegion.find("\"");
            if(q1.notNil, { q2 = searchRegion.find("\"", false, q1 + 1) });

            if(q1.notNil and: q2.notNil, {
                absByteStart = pos + q1 + 1;
                absByteEnd = pos + q2;
                dots = text[absByteStart..absByteEnd-1];

                registry[name] = (
                    pattern: pattern,
                    byteStart: absByteStart,
                    byteEnd: absByteEnd,
                    currentDots: dots,
                    dotCount: dots.size,
                );
            });
        });
    };

    registry;
};

"Helper ~scanControllersInText loaded.".postln;
)

// ==================== SUMMARY ====================
(
"".postln;
"=== MILESTONE 1 TEST SUMMARY ===".postln;
"".postln;
"Run order:".postln;
"  1. LOAD DEPENDENCIES - loads M0.9, sets target path".postln;
"  2. TEST 1.1 - Find known pattern (File.readAllString)".postln;
"  3. TEST 1.2 - Find dots in controller (File.readAllString)".postln;
"  4. TEST 1.3 - Parse all 7 controllers (File.readAllString)".postln;
"  5. TEST 1.4 - Verify with Document.selectRange (opens target in IDE)".postln;
"".postln;
"Test target: wildcard-visual-test-target.scd".postln;
"Registry stored in: ~m1Registry".postln;
)
