// ============================================================
// M5 WILDCARD - Chaos engine functions
// ============================================================
// Loaded by workspace.scd - do not run directly
// ============================================================

// === STATE ===
~wcRunning = false;
~wcLevel = 1;
~wcMutationCount = 0;
~wcRoutine = nil;

// === MUTATION SPECS ===
// Dots are the source of truth
~wcMutations = (
    jitter: (maxDots: 10, toValue: {|n| n / 10 * 0.3 }),
    speed:  (maxDots: 10, toValue: {|n| 0.5 + (n / 10 * 1.5) }),
    reverb: (maxDots: 10, toValue: {|n| n / 10 }),
);

// === CORE MUTATE ===
~wcMutate = {|name|
    var spec, dotCount, dots, value;
    name = name ? ~wcMutations.keys.choose;
    spec = ~wcMutations[name];

    dotCount = rrand(0, spec[\maxDots]);
    dots = String.fill(dotCount, $.);
    value = spec[\toValue].(dotCount);

    ~replaceContent.(~wcDoc, name, dots);

    ~wcMutationCount = ~wcMutationCount + 1;
    "[WC #%] % -> %".format(~wcMutationCount, name, dots).postln;
    (name: name, dots: dotCount, value: value);
};

// === START ===
~wcStart = {
    if (~wcRunning.not) {
        ~wcRunning = true;
        ~wcRoutine = {
            "[WC] Started (level %)".format(~wcLevel).postln;
            while { ~wcRunning } {
                ~wcMutate.();
                rrand(0.5, 3.0 - (~wcLevel * 0.4)).max(0.2).wait;
            };
            "[WC] Stopped".postln;
        }.fork(AppClock);
    };
};

// === STOP ===
~wcStop = {
    ~wcRunning = false;
};

// === SET LEVEL ===
~wcSetLevel = {|level|
    ~wcLevel = level.clip(1, 5);
    "[WC] Level: %".format(~wcLevel).postln;
};

"[WILDCARD] Loaded".postln;
