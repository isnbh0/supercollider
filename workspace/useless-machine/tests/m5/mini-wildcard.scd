// ============================================================
// MINI-WILDCARD - Minimal chaos engine for M5 testing
// ============================================================
// A stripped-down version of wildcard.scd to validate the
// visual mutation pattern before integrating into the real thing.
// ============================================================

// === LOAD UTILS ===
(
(thisProcess.nowExecutingPath.dirname +/+ "utils.scd").load;
)

// === SETUP: Get target document ===
(
var m5Dir = thisProcess.nowExecutingPath.dirname;
~miniTargetPath = m5Dir +/+ "test-target.scd";
~miniDoc = ~getOrOpenDoc.(~miniTargetPath);
"[MINI] Target: %".format(~miniTargetPath).postln;
)

// === STATE ===
(
~miniLevel = 1;           // 1-5 chaos intensity
~miniVisualMode = true;   // Toggle visual mutations
~miniRunning = false;
~miniMutationCount = 0;
)

// === MUTATIONS ===
// Dots are the source of truth. Each mutation defines:
//   - maxDots: maximum dot count
//   - toValue: convert dot count to runtime value
(
~miniMutations = (
    jitter: (maxDots: 10, toValue: {|n| n / 10 * 0.3 }),      // 0-10 dots -> 0.0-0.3
    speed:  (maxDots: 10, toValue: {|n| 0.5 + (n / 10 * 1.5) }), // 0-10 dots -> 0.5-2.0
    reverb: (maxDots: 10, toValue: {|n| n / 10 }),            // 0-10 dots -> 0.0-1.0
);
)

// === SINGLE MUTATION (for testing) ===
// Generate dot count first, then derive value from dots
(
~miniMutate = {|name|
    var spec, dotCount, dots, value;
    name = name ? ~miniMutations.keys.choose;
    spec = ~miniMutations[name];

    // Dots are the source of truth
    dotCount = rrand(0, spec[\maxDots]);
    dots = String.fill(dotCount, $.);
    value = spec[\toValue].(dotCount);

    if (~miniVisualMode) {
        ~replaceContent.(~miniDoc, name, dots);
    };

    ~miniMutationCount = ~miniMutationCount + 1;
    "[MINI #%] % -> % dots -> %".format(~miniMutationCount, name, dotCount, value.round(0.001)).postln;
    (dots: dotCount, value: value);
};
)

// === START/STOP ===
(
~miniStart = {
    if (~miniRunning.not) {
        ~miniRunning = true;
        ~miniRoutine = {
            "[MINI] Starting chaos (level %)".format(~miniLevel).postln;
            while { ~miniRunning } {
                ~miniMutate.();
                // Faster at higher levels
                rrand(0.5, 3.0 - (~miniLevel * 0.4)).max(0.2).wait;
            };
            "[MINI] Stopped".postln;
        }.fork(AppClock);
    } {
        "[MINI] Already running".postln;
    };
};

~miniStop = {
    ~miniRunning = false;
    "[MINI] Stop requested".postln;
};
)

// === CONVENIENCE ===
(
~miniSetLevel = {|level|
    ~miniLevel = level.clip(1, 5);
    "[MINI] Level set to %".format(~miniLevel).postln;
};

~miniToggleVisual = {
    ~miniVisualMode = ~miniVisualMode.not;
    "[MINI] Visual mode: %".format(~miniVisualMode).postln;
};

~miniStatus = {
    "=== MINI-WILDCARD STATUS ===".postln;
    "  Running: %".format(~miniRunning).postln;
    "  Level: %".format(~miniLevel).postln;
    "  Visual: %".format(~miniVisualMode).postln;
    "  Mutations: %".format(~miniMutationCount).postln;
    "  Target: %".format(~miniDoc.notNil.if({ ~miniDoc.title }, { "nil" })).postln;
};
)

// === RESET TARGET ===
(
~miniReset = {
    var original = "// ============================================================
// M5 TEST TARGET - Minimal fixture for mini-wildcard
// ============================================================

// === CONTROLLERS (mutation targets) ===
~jitter.(.....);
~speed.(....);
~reverb.(......);

// === UNICODE TEST (drift validation) ===
~korean.(한글);
~afterUnicode.(...);

// END_MARKER: OK
";
    var text, utf16Len;
    text = ~miniDoc.string;
    utf16Len = ~byteToUtf16.(text, text.size);
    ~miniDoc.selectRange(0, utf16Len);
    ~miniDoc.selectedString_(original);
    ~miniMutationCount = 0;
    "[MINI] Target reset".postln;
};
)

"[MINI-WILDCARD] Loaded".postln;

// ============================================================
// QUICK TEST COMMANDS (run individually with Cmd+Enter)
// ============================================================

~miniStatus.();           // Post window shows status table

~miniMutate.();           // Post: "[MINI #1] reverb -> 0.45 (....)" + target file changes

~miniMutate.(\jitter);    // Post: "[MINI #2] jitter -> ..." + ~jitter line changes in target

~miniStart.();            // Post: "[MINI] Starting chaos" + continuous mutations in target

~miniStop.();             // Post: "[MINI] Stop requested" then "[MINI] Stopped"

~miniSetLevel.(3);        // Post: "[MINI] Level set to 3" (affects mutation speed)

~miniToggleVisual.();     // Post: "[MINI] Visual mode: false" (mutations stop updating target)

~miniReset.();            // Target file restored to original, post: "[MINI] Target reset"
