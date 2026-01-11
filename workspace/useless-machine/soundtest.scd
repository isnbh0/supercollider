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

        // --- Loop Points Override ---
        // Each sample gets [loopStart, loopEnd] normalized to 0.0-1.0
        // Default: full sample range
        ~loopPoints = IdentityDictionary.new;
        ~samplePack.do {|buf, i|
            ~loopPoints[buf] = [0.0, 1.0];
        };

        // Set loop points for current sample
        ~setLoop = {|start = 0.0, end = 1.0|
            ~loopPoints[~genSample] = [start.clip(0.0, 1.0), end.clip(0.0, 1.0)];
            "Loop: " ++ start.round(0.001) ++ " → " ++ end.round(0.001);
        };
        ~setLoopStart = {|start = 0.0|
            var current = ~loopPoints[~genSample];
            ~loopPoints[~genSample] = [start.clip(0.0, 1.0), current[1]];
            "Loop start: " ++ start.round(0.001);
        };
        ~setLoopEnd = {|end = 1.0|
            var current = ~loopPoints[~genSample];
            ~loopPoints[~genSample] = [current[0], end.clip(0.0, 1.0)];
            "Loop end: " ++ end.round(0.001);
        };
        ~getLoop = {
            var lp = ~loopPoints[~genSample];
            "Loop: " ++ lp[0].round(0.001) ++ " → " ++ lp[1].round(0.001);
        };
        ~resetLoop = {
            ~loopPoints[~genSample] = [0.0, 1.0];
            "Loop reset to full sample";
        };

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

        "=== BOOT complete ===";
    });
};

// --- PREP: Set up generators, functions, and limiter ---
~prep = {
    // Configuration
    ~genSample = ~samplePack[6];
    ~genStartPos = 0.0;
    ~genStartRange = 0.0;

    // Generator specs: [prob, dur_sec, amp] - "original" preset (normal playback)
    ~genSpecs = [
        [0.0,  0.01,  0.7],   // id 0: off
        [0.0,  0.1,   0.5],   // id 1: off
        [0.0,  1.0,   0.4],   // id 2: off
        [1.0,  10.0,  0.25],  // id 3: full sample, always triggers
    ];

    // State tracking
    ~genWeights = [8, 4, 2, 1];
    ~genLastTrigger = [0, 0, 0, 0];
    ~genSynths = [nil, nil, nil, nil];
    ~genBase = [0, 1, 2, 3];

    // Behavior settings
    ~overrideProb = 0.0;
    ~tickRate = 40;
    ~tickRunning = false;
    ~silenceProb = 0.0;
    ~silenceDuration = 10;
    ~silenceCounter = 0;

    // Playhead mode: cycles through sample instead of random
    ~playheadMode = true;       // true = playhead, false = random
    ~playheadPos = 0.0;          // current position (0.0 to 1.0)
    ~playheadSpeedPct = 100;     // speed as percentage: 0=stopped, 100=normal, 200=2x
    ~playheadBaseRate = 0.4;     // base rate: full samples per second at 100%
    ~playheadAdvance = 0.01;     // computed per-tick advancement (updated by ~updateSpeed)
    ~playheadJitter = 0.0;       // zero jitter for clean playback

    // Recalculate per-tick advancement (call after changing speedPct or tickRate)
    ~updateSpeed = {
        ~playheadAdvance = (~playheadSpeedPct / 100) * ~playheadBaseRate / ~tickRate;
        "Speed: " ++ ~playheadSpeedPct.asString ++ "%";
    };
    ~updateSpeed.();  // initialize

    // Master limiter
    ~masterLevel = 0.8;
    ~limiterLevel = 0.95;
    if(~limiter.notNil, { ~limiter.free });
    ~limiter = {
        var sig = In.ar(0, 2) * ~masterLevel;
        ReplaceOut.ar(0, Limiter.ar(sig, ~limiterLevel, 0.01));
    }.play(addAction: \addToTail);

    // Fade times to avoid clicks
    ~fadeTime = 0.005;  // 5ms fade in/out

    // Reverb send amount
    ~genReverb = 0.0;  // 0.0 = dry, 1.0 = full reverb send

    // Modified sampler with attack/release envelope to prevent clicks
    SynthDef(\gen_sampler, {|sample = 0, start = 0, dur = 1, rate = 1, amp = 1.0, pan = 0.0, fade = 0.005, rev = 0.0|
        var srate = BufSampleRate.kr(sample);
        var frames = BufFrames.kr(sample);
        var startPos = frames * start;
        var phase = Line.ar(startPos, startPos + (srate * dur), dur * rate.abs.reciprocal);
        // Envelope with attack and release to prevent clicks
        var fadeIn = min(fade, dur * 0.3);
        var fadeOut = min(fade, dur * 0.3);
        var env = Env([0, 1, 1, 0], [fadeIn, dur - fadeIn - fadeOut, fadeOut], \sin).ar(Done.freeSelf);
        var sig = BufRd.ar(1, sample, phase) * env * amp;
        sig = Pan2.ar(sig, pan);
        Out.ar(0, sig);
        Out.ar(~reverbBus, sig * rev);
    }).add;

    // --- Helper Functions ---
    ~getStartPos = {
        var lp = ~loopPoints[~genSample] ?? [0.0, 1.0];
        var loopStart = lp[0];
        var loopEnd = lp[1];
        var loopRange = loopEnd - loopStart;
        var pos;

        if(~playheadMode, {
            // Playhead mode: position around playhead with jitter, mapped to loop range
            pos = (~playheadPos + ~playheadJitter.rand2).wrap(0.0, 1.0);
            loopStart + (pos * loopRange);
        }, {
            // Random mode: random position within range, mapped to loop range
            pos = ~genStartPos + (~genStartRange * 1.0.rand);
            loopStart + (pos.clip(0.0, 1.0) * loopRange);
        });
    };

    ~trigGen = {|id, startOverride|
        var spec = ~genSpecs[id];
        var start = startOverride ?? { ~getStartPos.() };
        ~genLastTrigger[id] = Main.elapsedTime;
        ~genSynths[id] = Synth(\gen_sampler, [
            \sample, ~genSample,
            \start, start.clip(0, 0.99),
            \dur, spec[1],
            \amp, spec[2],
            \pan, 1.0.rand2,
            \fade, ~fadeTime,
            \rev, ~genReverb,
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
        "Sample: " ++ newIdx.asString;
    };

    // Dot controller factory
    // Creates a controller: "" = minVal, "......." (numDots) = maxVal
    // exp: false = linear, true = exponential
    ~makeDot = {|name, minVal = 0.0, maxVal = 1.0, numDots = 10, exp = false|
        {|dots|
            var t = (dots.size / numDots).clip(0, 1);
            var val;
            if(exp, {
                // Exponential: good for frequencies, times
                val = minVal * ((maxVal / minVal) ** t);
            }, {
                // Linear
                val = t.linlin(0, 1, minVal, maxVal);
            });
            currentEnvironment[name] = val;
            name.asString ++ ": " ++ val.round(0.001).asString;
            val;
        };
    };

    // Shortcuts for common parameters
    ~rev = ~makeDot.(\genReverb, 0, 1);
    ~fade = ~makeDot.(\fadeTime, 0.001, 0.05, 10, true);  // exp: 1ms to 50ms
    ~master = ~makeDot.(\masterLevel, 0, 1);
    // Speed controller: 0 dots = 0%, 5 dots = 100%, 10 dots = 200%
    ~speed = {|dots|
        ~playheadSpeedPct = (dots.size / 10 * 200).clip(0, 200);
        ~updateSpeed.();
    };
    ~jitter = ~makeDot.(\playheadJitter, 0, 0.3);
    ~silence = ~makeDot.(\silenceProb, 0, 0.3);
    ~silenceDur = ~makeDot.(\silenceDuration, 1, 30);  // 1-30 ticks
    ~override = ~makeDot.(\overrideProb, 0, 0.3);
    ~startPos = ~makeDot.(\genStartPos, 0, 1);
    ~startRange = ~makeDot.(\genStartRange, 0, 0.5);

    // Loop point dot controllers
    ~loopStart = {|dots|
        var val = (dots.size / 10).clip(0, 1);
        ~setLoopStart.(val);
    };
    ~loopEnd = {|dots|
        var val = (dots.size / 10).clip(0, 1);
        ~setLoopEnd.(val);
    };

    // --- Presets: [prob, dur_sec, amp] for each generator ---
    ~presets = (
        original: [
            [0.0,   0.01,  0.7],
            [0.0,   0.1,   0.5],
            [1.0,   1.0,   0.4],
            [0.0,   10.0,  0.25],
        ],
        normal: [
            [0.3,   0.01,  0.7],
            [0.2,   0.1,   0.5],
            [0.08,  1.0,   0.4],
            [0.01,  10.0,  0.25],
        ],
        ambient: [
            [0.05,  0.1,   0.4],
            [0.02,  0.5,   0.35],
            [0.01,  2.0,   0.3],
            [0.005, 10.0,  0.25],
        ],
        stutter: [
            [0.9,   0.01,  0.5],
            [0.7,   0.02,  0.45],
            [0.3,   0.05,  0.4],
            [0.01,  1.0,   0.3],
        ],
    );

    ~preset = {|name|
        var p = ~presets[name];
        if(p.notNil, {
            ~genSpecs = p.deepCopy;
            "Preset: " ++ name.asString;
        }, {
            "Unknown preset: " ++ name.asString;
        });
    };

    "=== PREP complete ===";
};

// --- START: Begin the tick ---
~start = {
    if(~tickRunning == false, {
        ~tickRunning = true;
        ~silenceCounter = 0;
        ~tickRoutine = {
            var interval = ~tickRate.reciprocal;
            var modeStr = if(~playheadMode, { "playhead" }, { "random" });
            ~tickRate.asString ++ "Hz (" ++ modeStr ++ ")";
            inf.do {
                // Advance playhead (always, even during silence)
                if(~playheadMode, {
                    ~playheadPos = (~playheadPos + ~playheadAdvance).wrap(0.0, 1.0);
                });

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
        "=== START ===";
    }, {
        "Already running";
    });
};

// --- STOP: Stop the tick ---
~stop = {
    if(~tickRunning, {
        ~tickRoutine.stop;
        ~tickRunning = false;
        "Stopped";
    });
};

"Definitions loaded. Run ~boot.(), ~prep.(), ~start.()";
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

// Dot controllers: "" = min, ".........." = max
// Initial values synced with PREP defaults

( ~rev.(  // reverb: dry → wet (init: 0)
    "..."
))

( ~fade.(  // fade: 1ms → 50ms exp (init: 5ms)
    "...."
))

( ~master.(  // master volume: 0 → 1 (init: 0.8)
    "........"
))

( ~speed.(  // playhead: 0% → 100%="....." → 200% (init: 100%)
    "....."
))

( ~jitter.(  // jitter: 0 → 0.3 (init: 0)
    ""
))

( ~silence.(  // silence prob: 0 → 0.3 (init: 0)
    ""
))

( ~silenceDur.(  // silence ticks: 1 → 30 (init: 10)
    "..."
))

( ~override.(  // override prob: 0 → 0.3 (init: 0)
    ""
))

( ~startPos.(  // start pos: 0 → 1 (init: 0)
    ""
))

( ~startRange.(  // start range: 0 → 0.5 (init: 0)
    ""
))

// Loop points: constrain playback to a portion of the sample
~getLoop.();  // show current loop points
~setLoop.(0.0, 1.0);  // set both start and end
~setLoopStart.(0.0);  // just start
~setLoopEnd.(1.0);    // just end
~resetLoop.();        // reset to full sample

( ~loopStart.(  // loop start: 0 → 1 (init: 0)
    ""
))

( ~loopEnd.(  // loop end: 0 → 1 (init: 1)
    ".........."
))

// Presets
~preset.(\original);
~preset.(\normal);
~preset.(\ambient);
~preset.(\stutter);

// Toggle playhead mode (restart to see message)
~playheadMode = true;  ~stop.(); ~start.();   // playhead mode
~playheadMode = false; ~stop.(); ~start.();   // random mode

// Restart with new tick rate
~tickRate = 60;
~stop.(); ~start.();


// ==================== ADJUSTMENTS ====================
// Use dot controllers: "" = min, ".........." = max

// Sample
~genSample = ~samplePack[0];   // Amen break
~genSample = ~samplePack[4];   // Piano
~genSample = ~samplePack[6];   // First Class Piano

// Loop points (per sample)
~getLoop.();               // show current
~setLoop.(0.2, 0.8);       // set start/end
~resetLoop.();             // reset to full
( ~loopStart.(  // init: 0
    ""
))
( ~loopEnd.(  // init: 1
    ".........."
))

// Generator specs (use presets instead)
~preset.(\normal);

// Position (random mode)
( ~startPos.(  // init: 0
    ""
))
( ~startRange.(  // init: 0
    ""
))

// Behavior
( ~override.(  // init: 0
    ""
))
( ~silence.(  // init: 0
    ""
))
( ~silenceDur.(  // init: 10
    "..."
))
( ~fade.(  // init: 0.005
    "...."
))
( ~rev.(  // init: 0
    ""
))

// Playhead settings
( ~speed.(  // init: 100%
    "....."
))
( ~jitter.(  // init: 0
    ""
))
~playheadPos = 0.0;  // reset playhead

// Master level
( ~master.(  // init: 0.8
    "........"
))
