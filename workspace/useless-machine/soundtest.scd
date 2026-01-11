// ================================================================================
// 4 GENERATORS SOUNDCHECK
//
// Usage:
//   ~boot.();   // Boot server and load samples
//   ~prep.();   // Set up generators and limiter
//   ~start.();  // Start the tick
//   ~stop.();   // Stop the tick
// ================================================================================


// ==================== DEFINITIONS ====================
(
// --- BOOT: Server setup and load samples ---
~boot = {
    s.options.memSize_(pow(2, 14));
    s.waitForBoot({
        // Reset initialization flag and load glitch-loader
        ~initialized = nil;
        (Document.current.dir ++ "/glitch-loader.scd").load;

        // Set delay time
        ~setDelayTime.([0.25, 0.33]);

        // LFOs
        Ndef(\lfo, {
            Out.kr(~lfo[0], SinOsc.kr(0.3).range(1, 4));
            Out.kr(~lfo[1], LFTri.kr(0.3, 3).range(1, 4));
            Out.kr(~lfo[2], LFSaw.kr(3.1, 1).range(1, 4));
            Out.kr(~lfo[3], LFPulse.kr(3).range(1, 4));
            Out.kr(~lfo[4], LFNoise0.kr(3).range(1, 4));
            Out.kr(~lfo[5], LFNoise1.kr(3).range(1, 4));
        }).play;

        // Tempo
        TempoClock.tempo_(140/60);

        "=== BOOT complete ===".postln;
    });
};

// --- PREP: Set up generators, functions, and limiter ---
~prep = {
    // Configuration
    ~genSample = ~samplePack[6];
    ~genStartPos = 0.0;
    ~genStartRange = 0.25;

    // Generator specs: [prob, dur_sec, amp]
    ~genSpecs = [
        [0.5,   0.01,  0.9],   // id 0: dur=10ms,   loud
        [0.08,  0.1,   0.6],   // id 1: dur=100ms,  medium
        [0.008, 1.0,   0.4],   // id 2: dur=1s,     soft
        [0.001, 10.0,  0.25],  // id 3: dur=10s,    very soft
    ];

    // State tracking
    ~genWeights = [8, 4, 2, 1];
    ~genLastTrigger = [0, 0, 0, 0];
    ~genSynths = [nil, nil, nil, nil];
    ~genBase = [0, 1, 2, 3];

    // Behavior settings
    ~overrideProb = 0.05;
    ~tickRate = 40;
    ~tickRunning = false;
    ~silenceProb = 0.05;
    ~silenceDuration = 10;
    ~silenceCounter = 0;

    // Master limiter
    ~masterLevel = 0.8;
    ~limiterLevel = 0.95;
    if(~limiter.notNil, { ~limiter.free });
    ~limiter = {
        var sig = In.ar(0, 2) * ~masterLevel;
        ReplaceOut.ar(0, Limiter.ar(sig, ~limiterLevel, 0.01));
    }.play(addAction: \addToTail);

    // --- Helper Functions ---
    ~trigGen = {|id, startOverride|
        var spec = ~genSpecs[id];
        var start = startOverride ?? { ~genStartPos + (~genStartRange * 1.0.rand) };
        ~genLastTrigger[id] = Main.elapsedTime;
        ~genSynths[id] = Synth(\wesa_sampler, [
            \sample, ~genSample,
            \start, start.clip(0, 0.99),
            \dur, spec[1],
            \amp, spec[2],
            \pan, 1.0.rand2,
        ]);
    };

    ~haltGen = {|id|
        if(~genSynths[id].notNil, {
            ~genSynths[id].free;
            ~genSynths[id] = nil;
        });
    };

    ~isGenBusy = {|id|
        var spec = ~genSpecs[id];
        var elapsed = Main.elapsedTime - ~genLastTrigger[id];
        elapsed < spec[1];
    };

    ~tryTrigGen = {|id, startOverride|
        var busy = ~isGenBusy.(id);
        if(busy == false, {
            ~trigGen.(id, startOverride);
            true;
        }, {
            if(~overrideProb.coin, {
                ~haltGen.(id);
                ~trigGen.(id, startOverride);
                true;
            }, {
                false;
            });
        });
    };

    ~randomSample = {
        var current = ~samplePack.indexOf(~genSample);
        var choices = (0..(~samplePack.size - 1)).reject {|i| i == current };
        var newIdx = choices.choose;
        ~genSample = ~samplePack[newIdx];
        ("Sample: " ++ newIdx.asString).postln;
    };

    "=== PREP complete ===".postln;
};

// --- START: Begin the tick ---
~start = {
    if(~tickRunning == false, {
        ~tickRunning = true;
        ~silenceCounter = 0;
        ~tickRoutine = {
            var interval = ~tickRate.reciprocal;
            (~tickRate.asString ++ "Hz tick started").postln;
            inf.do {
                if(~silenceCounter > 0, {
                    ~silenceCounter = ~silenceCounter - 1;
                }, {
                    if(~silenceProb.coin, {
                        ~silenceCounter = ~silenceDuration;
                    }, {
                        4.do {|id|
                            var prob = ~genSpecs[id][0];
                            if(prob.coin, {
                                ~tryTrigGen.(id);
                            });
                        };
                    });
                });
                interval.wait;
            };
        }.fork;
    }, {
        "Already running".postln;
    });
};

// --- STOP: Stop the tick ---
~stop = {
    if(~tickRunning, {
        ~tickRoutine.stop;
        ~tickRunning = false;
        "Stopped".postln;
    });
};

"Definitions loaded. Run ~boot.(), ~prep.(), ~start.()".postln;
)


// ==================== RUN ====================
~boot.();
~prep.();
~start.();
~stop.();


// ==================== CONTROLS ====================

// Trigger individual generators
~trigGen.(0);
~trigGen.(1);
~trigGen.(2);
~trigGen.(3);

// Random sample
~randomSample.();

// Restart with new tick rate
~tickRate = 60;
~stop.(); ~start.();


// ==================== ADJUSTMENTS ====================

// Sample
~genSample = ~samplePack[0];   // Amen break
~genSample = ~samplePack[4];   // Piano
~genSample = ~samplePack[6];   // First Class Piano

// Position
~genStartPos = 0.0;
~genStartRange = 0.5;

// Generator specs: [prob, dur_sec, amp]
~genSpecs[0] = [0.5, 0.01, 0.9];
~genSpecs[1] = [0.08, 0.1, 0.6];
~genSpecs[2] = [0.008, 1.0, 0.4];
~genSpecs[3] = [0.001, 10.0, 0.25];

// Behavior
~overrideProb = 0.05;
~silenceProb = 0.05;
~silenceDuration = 10;

// Master level (re-run to apply)
~masterLevel = 0.6;
~limiter.free; ~limiter = { ReplaceOut.ar(0, Limiter.ar(In.ar(0, 2) * ~masterLevel, ~limiterLevel, 0.01)) }.play(addAction: \addToTail);
