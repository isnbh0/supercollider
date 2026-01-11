// ================================================================================
// 4 GENERATORS SOUNDCHECK
// ================================================================================
//
// ╔════════════════════════════════════════════════════════════════════════════╗
// ║                         QUICK START (RUN IN ORDER)                         ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  1. ( ~boot.(); )     // Boot server, load samples                         ║
// ║  2. ( ~prep.(); )     // Set up generators                                 ║
// ║  3. ( ~start.(); )    // Start playback                                    ║
// ║  4. ( ~stop.(); )     // Stop playback                                     ║
// ╚════════════════════════════════════════════════════════════════════════════╝
//
// ╔════════════════════════════════════════════════════════════════════════════╗
// ║                              WILDCARD SETUP                                ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  LOAD:    ( (Document.current.dir ++ "/wildcard.scd").load; )              ║
// ║  START:   ( ~wildcardStart.(); )    // auto-saves state first              ║
// ║  STOP:    ( ~wildcardStop.(); )                                            ║
// ║  RECOVER: ( ~wildcardRecover.(); )  // stop + restore saved state          ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  LEVELS:  ( ~wildcardSetLevel.(1); )  // 1=subtle, 5=total chaos           ║
// ║  CODA:    ( ~wildcardCoda.(); )       // 30-sec final collapse!            ║
// ╚════════════════════════════════════════════════════════════════════════════╝
//
// ╔════════════════════════════════════════════════════════════════════════════╗
// ║                            RESTART EVERYTHING                              ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  If things go wrong:                                                       ║
// ║    1. ( ~stop.(); )                                                        ║
// ║    2. ( ~wildcardStop.(); )       // if wildcard running                   ║
// ║    3. ( ~stateRestore.(); )       // restore saved params                  ║
// ║    4. ( ~start.(); )              // restart clean                         ║
// ║                                                                            ║
// ║  Nuclear option (full reset):                                              ║
// ║    1. Cmd+. (stop all sound)                                               ║
// ║    2. ( ~boot.(); )                                                        ║
// ║    3. ( ~prep.(); )                                                        ║
// ║    4. ( ~start.(); )                                                       ║
// ╚════════════════════════════════════════════════════════════════════════════╝
//
// ╔════════════════════════════════════════════════════════════════════════════╗
// ║                           QUICK ADJUSTMENTS                                ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  SAMPLE:   ~genSample = ~samplePack[6];   // 0-8, see list below           ║
// ║  SPEED:    ( ~speed.("....."); )          // 5 dots = 100%                 ║
// ║  VOLUME:   ( ~master.("........"); )      // 8 dots = 80%                  ║
// ║  REVERB:   ( ~rev.("..."); )              // 0-10 dots                     ║
// ║  PRESET:   ~preset.(\normal);             // \original \normal \ambient    ║
// ║  LOOP:     ~setLoop.(0.0, 0.85);          // start, end (0-1)              ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  STATE:    ( ~stateSnapshot.(); )         // save current params           ║
// ║            ( ~stateRestore.(); )          // restore saved params          ║
// ╚════════════════════════════════════════════════════════════════════════════╝
//
// ================================================================================


// ==================== DEFINITIONS ====================
(
// --- BOOT: Server setup and load samples ---
~boot = {
    // Immediately invalidate ready state (prevents race condition after server restart)
    ~soundtestReady = false;

    // Stop any running routines from previous session (prevents closure errors)
    if(~wildcardRoutine.notNil, { ~wildcardRoutine.stop; ~wildcardRoutine = nil });
    if(~tickRoutine.notNil, { ~tickRoutine.stop });
    if(~escalationRoutine.notNil, { ~escalationRoutine.stop });

    s.options.memSize_(pow(2, 14));
    s.waitForBoot({
        // Reset state flags (important after server reboot)
        ~tickRunning = false;
        ~tickRoutine = nil;
        ~genSynths = [nil, nil, nil, nil];

        // Reset initialization flag and load glitch-loader
        ~initialized = nil;
        (Document.current.dir ++ "/glitch-loader.scd").load;

        // Wait for all buffers to finish loading before accessing their properties
        s.sync;

        // Validate loaded buffers - remove any that failed to load
        ~samplePack = ~samplePack.select({|buf, i|
            var valid = buf.numFrames > 0;
            if(valid.not, {
                ("WARNING: Buffer " ++ i ++ " failed to load (0 frames)").postln;
            });
            valid;
        });

        if(~samplePack.size == 0, {
            "ERROR: No samples loaded! Check samplepack directory.".postln;
            // Don't use ^nil in callback - just exit this block
            // The callback will return nil naturally
        }, {

        ("Loaded " ++ ~samplePack.size ++ " samples successfully").postln;

        // --- Loop Points Override ---
        // Each sample gets [loopStart, loopEnd] normalized to 0.0-1.0
        // Default: full sample range
        ~loopPoints = IdentityDictionary.new;
        ~samplePack.do {|buf, i|
            ~loopPoints[buf] = [0.0, 1.0];
        };
        // Sample-specific loop points
        ~loopPoints[~samplePack[6]] = [0.0, 0.85];  // First Class Piano

        // Sample registry with metadata (for wildcard)
        ~sampleRegistry = ~samplePack.collect {|buf, i|
            (
                buffer: buf,
                index: i,
                name: PathName(buf.path).fileNameWithoutExtension,
                duration: buf.duration,
                channels: buf.numChannels,
            )
        };

        // Set loop points for current sample
        ~setLoop = {|start = 0.0, end = 1.0|
            ~loopPoints[~genSample] = [start.clip(0.0, 1.0), end.clip(0.0, 1.0)];
            "Loop: " ++ start.round(0.001) ++ " → " ++ end.round(0.001);
        };
        ~setLoopStart = {|start = 0.0|
            var current = ~loopPoints[~genSample] ?? [0.0, 1.0];
            ~loopPoints[~genSample] = [start.clip(0.0, 1.0), current[1]];
            "Loop start: " ++ start.round(0.001);
        };
        ~setLoopEnd = {|end = 1.0|
            var current = ~loopPoints[~genSample] ?? [0.0, 1.0];
            ~loopPoints[~genSample] = [current[0], end.clip(0.0, 1.0)];
            "Loop end: " ++ end.round(0.001);
        };
        ~getLoop = {
            var lp = ~loopPoints[~genSample] ?? [0.0, 1.0];
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
        }); // end of if(~samplePack.size == 0) else block
    });
};

// --- PREP: Set up generators, functions, and limiter ---
~prep = {
    // Guard: ensure boot completed
    if(~samplePack.isNil or: { ~samplePack.size == 0 }, {
        "오류: ~boot.() 먼저 실행하고 'BOOT complete' 메시지를 기다리세요".postln;
        "Error: Run ~boot.() first and wait for 'BOOT complete'".postln;
        ^nil;
    });

    // Configuration - use bounds-safe index (prefer index 6, fallback to last available)
    ~genSample = ~samplePack[6.min(~samplePack.size - 1)];
    ~genStartPos = 0.0;
    ~genStartRange = 0.0;

    // Generator specs: [prob, dur_sec, amp] - "original" preset (normal playback)
    // @wildcard STUTTER:
    //   ~genSpecs[0..3][0] - probability (0-1)
    //   ~genSpecs[0..3][1] - duration (0.001-10 sec)
    //   ~genSpecs[0..3][2] - amplitude (0-1)
    ~genSpecs = [
        [0.0,  0.01,  0.7],   // id 0: off
        [0.0,  0.1,   0.5],   // id 1: off
        [1.0,  1.0,   0.4],   // id 2: off
        [0.0,  10.0,  0.25],  // id 3: full sample, always triggers
    ];

    // Getter functions for genSpecs (allows wildcard to affect mid-tick)
    ~getGenProb = {|id| ~genSpecs[id][0] };
    ~getGenDur = {|id| ~genSpecs[id][1] };
    ~getGenAmp = {|id| ~genSpecs[id][2] };

    // State tracking
    ~genWeights = [8, 4, 2, 1];
    ~genLastTrigger = [0, 0, 0, 0];
    ~genSynths = [nil, nil, nil, nil];
    ~genBase = [0, 1, 2, 3];

    // Behavior settings
    // @wildcard: overrideProb [0, 1] - probability to interrupt busy generator
    ~overrideProb = 0.0;
    // @wildcard: tickRate [1, 200] - ticks per second
    ~tickRate = 40;
    ~tickRunning = false;
    // @wildcard: silenceProb [0, 1] - probability of silence gap
    ~silenceProb = 0.0;
    ~silenceDuration = 10;
    ~silenceCounter = 0;

    // Debug mode
    ~debug = false;
    ~debugInterval = 10;  // print every N ticks
    ~debugTick = 0;

    // Seamless mode: synths overlap instead of being halted
    ~seamlessMode = false;

    // Playhead mode: cycles through sample instead of random
    ~playheadMode = true;       // true = playhead, false = random
    ~playheadPos = 0.0;          // current position (0.0 to 1.0)
    // @wildcard: playheadSpeedPct [0, 500] - playback speed percentage
    ~playheadSpeedPct = 100;     // speed as percentage: 0=stopped, 100=normal, 200=2x
    ~playheadBaseRate = 0.4;     // base rate: full samples per second at 100%
    ~playheadAdvance = 0.01;     // computed per-tick advancement (updated by ~updateSpeed)
    // @wildcard: playheadJitter [0, 1] - start position randomization
    ~playheadJitter = 0.0;       // zero jitter for clean playback

    // Recalculate per-tick advancement (call after changing speedPct or tickRate)
    ~updateSpeed = {
        ~playheadAdvance = (~playheadSpeedPct / 100) * ~playheadBaseRate / ~tickRate;
        "Speed: " ++ ~playheadSpeedPct.asString ++ "%";
    };
    ~updateSpeed.();  // initialize

    // Get sample duration in seconds
    ~getSampleDur = {
        ~genSample.duration;
    };

    // Calculate proper duration for original playback (matches playhead advance)
    ~calcOriginalDur = {|verbose = false|
        var sampleDur = ~genSample.duration;
        var lp = ~loopPoints[~genSample] ?? [0.0, 1.0];
        var loopRange = lp[1] - lp[0];
        var loopDur = sampleDur * loopRange;
        // Duration = fraction of sample per tick × actual sample duration
        // (loopRange already applied by getStartPos mapping)
        var dur = ~playheadAdvance * sampleDur;
        if(verbose, {
            postf("calcOriginalDur:\n");
            postf("  sampleDur=%.3fs loopRange=% loopDur=%.3fs\n", sampleDur, loopRange.round(0.001), loopDur);
            postf("  playheadAdvance=% (per tick)\n", ~playheadAdvance.round(0.00001));
            postf("  tickRate=%Hz interval=%.4fs\n", ~tickRate, ~tickRate.reciprocal);
            postf("  dur per tick = advance * sampleDur = %.5fs\n", dur);
            postf("  expected full loop time = %.3fs (%ticks)\n", loopDur / (~playheadAdvance * sampleDur / ~tickRate.reciprocal), (loopRange / ~playheadAdvance).round(1));
        });
        dur;
    };

    // Simple continuous playback (true original - plays loop region once)
    ~listenLoop = {
        var lp = ~loopPoints[~genSample] ?? [0.0, 1.0];
        var loopRange = lp[1] - lp[0];
        var dur = ~genSample.duration * loopRange;
        Synth(\gen_sampler, [
            \sample, ~genSample,
            \start, lp[0],
            \dur, dur,
            \amp, 0.5,
            \pan, 0,
            \fade, 0.01,
            \rev, ~genReverb,
        ]);
        "Playing loop: " ++ dur.round(0.01) ++ "s";
    };

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
    // Reads mono from buffer (safe for both mono and stereo - reads first channel)
    SynthDef(\gen_sampler, {|sample = 0, start = 0, dur = 1, rate = 1, amp = 1.0, pan = 0.0, fade = 0.005, rev = 0.0|
        var srate = BufSampleRate.kr(sample);
        var frames = BufFrames.kr(sample);
        var startPos = frames * start;
        // Guard against rate=0 (division by zero) - use small epsilon
        var safeRate = Select.kr(rate.abs < 0.001, [rate.abs, 0.001]);
        // Calculate phase direction based on rate sign
        var phaseDur = dur * safeRate.reciprocal;
        var phaseEnd = startPos + (srate * dur);
        // Forward: startPos -> phaseEnd, Reverse: phaseEnd -> startPos
        var phaseFwd = Line.ar(startPos, phaseEnd, phaseDur);
        var phaseRev = Line.ar(phaseEnd, startPos, phaseDur);
        var phase = Select.ar(rate >= 0, [phaseRev, phaseFwd]);
        // Envelope with attack and release to prevent clicks
        // Minimum 1ms floor to avoid known SC bug with very short envelopes
        var fadeIn = fade.min(dur * 0.3).max(0.001);
        var fadeOut = fade.min(dur * 0.3).max(0.001);
        // Ensure sustain time is never negative
        var sustainTime = (dur - fadeIn - fadeOut).max(0.001);
        var env = Env([0, 1, 1, 0], [fadeIn, sustainTime, fadeOut], \sin).ar(Done.freeSelf);
        // Read mono (numChannels=1) - safe for both mono and stereo buffers
        // For stereo buffers, this reads the left channel only
        var sig = BufRd.ar(1, sample, phase) * env * amp;
        sig = Pan2.ar(sig, pan);
        Out.ar(0, sig);
        Out.ar(~reverbBus, sig * rev);
    }).add;

    // Wait for SynthDef to compile on server before allowing synth creation
    // Note: s.sync requires Routine context, so we fork here
    fork {
        s.sync;
        "SynthDef compiled".postln;
    };

    // --- Helper Functions ---
    ~getStartPos = {
        var lp = ~loopPoints[~genSample] ?? [0.0, 1.0];
        var loopStart = lp[0];
        var loopEnd = lp[1];
        var loopRange = loopEnd - loopStart;
        var pos, result;

        if(~playheadMode, {
            // Playhead mode: position around playhead with jitter, mapped to loop range
            pos = (~playheadPos + ~playheadJitter.rand2).wrap(0.0, 1.0);
            result = loopStart + (pos * loopRange);
        }, {
            // Random mode: random position within range, mapped to loop range
            pos = ~genStartPos + (~genStartRange * 1.0.rand);
            result = loopStart + (pos.clip(0.0, 1.0) * loopRange);
        });

        if(~debug, {
            postf("  getStartPos: playhead=% pos=% loop=[%,%] result=%\n",
                ~playheadPos.round(0.0001), pos.round(0.0001),
                loopStart.round(0.001), loopEnd.round(0.001), result.round(0.0001));
        });
        result;
    };

    ~trigGen = {|id, startOverride|
        var spec = ~genSpecs[id];
        var start = startOverride ?? { ~getStartPos.() };
        var startClipped = start.clip(0, 0.99);
        var sampleDur = ~genSample.duration;
        var startSec = startClipped * sampleDur;
        var endSec = startSec + spec[1];

        if(~debug, {
            postf("TRIG[%]: start=% (%s) dur=%s end=%s | sampleDur=%s\n",
                id, startClipped.round(0.0001),
                startSec.round(0.001).asString ++ "s",
                spec[1].round(0.0001).asString ++ "s",
                endSec.round(0.001).asString ++ "s",
                sampleDur.round(0.01).asString ++ "s");
        });

        ~genLastTrigger[id] = Main.elapsedTime;
        ~genSynths[id] = Synth(\gen_sampler, [
            \sample, ~genSample,
            \start, startClipped,
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
        if(~seamlessMode, {
            // Seamless mode: always trigger, let synths overlap (they free themselves)
            ~trigGen.(id, startOverride);
            true;
        }, {
            // Normal mode: check if busy
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
        });
    };

    ~randomSample = {
        var current = ~samplePack.indexOf(~genSample);
        var choices = (0..(~samplePack.size - 1)).reject {|i| i == current };
        var newIdx;
        // Guard: need at least 2 samples to switch
        if(choices.size == 0, {
            "Only 1 sample available, cannot switch";
        }, {
            newIdx = choices.choose;
            ~genSample = ~samplePack[newIdx];
            "Sample: " ++ newIdx.asString;
        });
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

    // Original playback mode: synth duration matches playhead advancement
    // This creates seamless playback that sounds like the original sample
    ~originalMode = {
        var dur = ~calcOriginalDur.(true);  // verbose
        // Use slightly longer duration for crossfade overlap (avoids gaps)
        var overlapDur = dur * 1.2;
        ~genSpecs = [
            [0.0,  0.01,  0.7],   // off
            [0.0,  0.1,   0.5],   // off
            [0.0,  1.0,   0.4],   // off
            [1.0,  overlapDur, 0.4],   // always trigger with calculated duration + overlap
        ];
        // Enable seamless mode: synths overlap instead of being halted
        ~seamlessMode = true;
        // Center pan for original playback
        postf("\n=== ORIGINAL MODE ===\n");
        postf("dur per tick: %.4fs (base) -> %.4fs (with 20%% overlap)\n", dur, overlapDur);
        postf("seamlessMode: true (synths overlap)\n");
        postf("Expected: smooth playback matching original sample\n");
        "Original mode configured";
    };

    // Return to normal glitchy mode
    ~glitchMode = {
        ~seamlessMode = false;
        ~preset.(\normal);
        "Glitch mode: seamlessMode=false, preset=normal";
    };

    // === WILDCARD HELPERS ===
    // Burst all generators simultaneously
    ~burstAll = {|amp = 0.5|
        4.do {|i|
            var spec = ~genSpecs[i];
            ~genSynths[i] = Synth(\gen_sampler, [
                \sample, ~genSample,
                \start, 1.0.rand,
                \dur, spec[1],
                \amp, amp,
                \pan, 1.0.rand2,
                \fade, ~fadeTime,
                \rev, ~genReverb,
            ]);
        };
        "BURST: all generators triggered";
    };

    // Silence all generators
    ~silenceAll = {
        4.do {|i| ~haltGen.(i) };
        "SILENCE: all generators halted";
    };

    // State snapshot/restore (for wildcard recovery)
    ~stateSnapshot = {
        ~savedState = (
            genSpecs: ~genSpecs.deepCopy,
            genSample: ~genSample,
            playheadJitter: ~playheadJitter,
            playheadSpeedPct: ~playheadSpeedPct,
            tickRate: ~tickRate,
            masterLevel: ~masterLevel,
            genReverb: ~genReverb,
            fadeTime: ~fadeTime,
            silenceProb: ~silenceProb,
            overrideProb: ~overrideProb,
            loopPoints: ~loopPoints.copy,
            seamlessMode: ~seamlessMode,
            playheadMode: ~playheadMode,
        );
        "State snapshot saved";
    };

    ~stateRestore = {
        if(~savedState.notNil, {
            ~genSpecs = ~savedState.genSpecs.deepCopy;
            ~genSample = ~savedState.genSample;
            ~playheadJitter = ~savedState.playheadJitter;
            ~playheadSpeedPct = ~savedState.playheadSpeedPct;
            ~tickRate = ~savedState.tickRate;
            ~masterLevel = ~savedState.masterLevel;
            ~genReverb = ~savedState.genReverb;
            ~fadeTime = ~savedState.fadeTime;
            ~silenceProb = ~savedState.silenceProb;
            ~overrideProb = ~savedState.overrideProb;
            ~loopPoints = ~savedState.loopPoints.copy;
            ~seamlessMode = ~savedState.seamlessMode;
            ~playheadMode = ~savedState.playheadMode;
            ~updateSpeed.();
            "State restored";
        }, {
            "No saved state";
        });
    };

    // Wildcard integration flag
    ~soundtestReady = true;
    ~soundtestVersion = "1.1";

    "=== PREP complete ===";
};

// --- START: Begin the tick ---
~start = {
    // Guard: ensure prep completed
    if(~soundtestReady != true, {
        "오류: ~prep.() 먼저 실행하세요".postln;
        "Error: Run ~prep.() first".postln;
        ^nil;
    });

    if(~tickRunning == false, {
        ~tickRunning = true;
        ~silenceCounter = 0;
        ~tickRoutine = {
            var interval = ~tickRate.reciprocal;
            var modeStr = if(~playheadMode, { "playhead" }, { "random" });
            ~tickRate.asString ++ "Hz (" ++ modeStr ++ ")";
            inf.do {
                // Debug: periodic status
                if(~debug && ((~debugTick % ~debugInterval) == 0), {
                    postf("\n--- TICK % | playhead=% advance=% ---\n",
                        ~debugTick, ~playheadPos.round(0.0001), ~playheadAdvance.round(0.00001));
                });
                ~debugTick = ~debugTick + 1;

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
        ~tickRoutine = nil;
        ~tickRunning = false;
        // Free any running generator synths
        4.do {|id| ~haltGen.(id) };
        "Stopped";
    });
};

"Definitions loaded. Run ~boot.(), ~prep.(), ~start.()";
)

// ==================== CONTROLS ====================

// Dot controllers: "" = min, ".........." = max
// Initial values synced with PREP defaults

( ~rev.(  // reverb: dry → wet (init: 0)
    "........."
))

( ~fade.(  // fade: 1ms → 50ms exp (init: 5ms)
    ""
))


( ~speed.(  // playhead: 0% → 100%="....." → 200% (init: 100%)
    ""
))

( ~jitter.(  // jitter: 0 → 0.3 (init: 0)
    "...."
))

( ~silence.(  // silence prob: 0 → 0.3 (init: 0)
    ".........."
))

( ~silenceDur.(  // silence ticks: 1 → 30 (init: 10)
    "..."
))

( ~override.(  // override prob: 0 → 0.3 (init: 0)
    ""
))

( ~startPos.(  // start pos: 0 → 1 (init: 0)
    ".."
))

( ~startRange.(  // start range: 0 → 0.5 (init: 0)
    ""
))

( ~loopStart.(  // loop start: 0 → 1 (init: 0)
    ""
))

( ~loopEnd.(  // loop end: 0 → 1 (init: 1)
    "........."
))

// ==================== ADJUSTMENTS ====================














// ============================================================
// ============================================================
// WILDCARD VISUAL MODE - MILESTONE 0.5: COORDINATE SYSTEM DEEP DIVE
// ============================================================
// ============================================================
//
// PURPOSE: Understand the relationship between:
//   - doc.string positions (String indexing)
//   - doc.selectRange positions (Document API)
//   - Unicode/UTF-8 effects on both
//
// RUN EACH TEST BLOCK (Cmd+Enter)
// ============================================================

// ==================== TEST 0.5a ====================
// Basic sanity check: select known positions at start of file
(
var doc = Document.current;
var text = doc.string;

"".postln;
"=== TEST 0.5a: Select at start of file ===".postln;

// Select first 10 characters
doc.selectRange(0, 10);
"selectRange(0, 10): '%'".format(doc.selectedString).postln;
"text[0..9]:         '%'".format(text[0..9]).postln;
"Match: %".format(doc.selectedString == text[0..9]).postln;
"".postln;

// Select characters 50-60
doc.selectRange(50, 10);
"selectRange(50, 10): '%'".format(doc.selectedString).postln;
"text[50..59]:        '%'".format(text[50..59]).postln;
"Match: %".format(doc.selectedString == text[50..59]).postln;
"".postln;
)

// ==================== TEST 0.5b ====================
// Find first unicode character and measure drift
(
var doc = Document.current;
var text = doc.string;
var unicodePositions = List.new;
var driftLog = List.new;

"".postln;
"=== TEST 0.5b: Find unicode chars and measure drift ===".postln;

// Scan for non-ASCII bytes
text.size.min(5000).do {|i|
    var byte = text[i].ascii;
    if(byte < 0 or: { byte > 127 }, {
        unicodePositions.add(i);
    });
};

"Found % non-ASCII bytes in first 5000 chars".format(unicodePositions.size).postln;

if(unicodePositions.size > 0, {
    "First 20 non-ASCII positions: %".format(unicodePositions[0..19]).postln;

    // Test selection at various points
    [100, 500, 1000, 2000, 5000, 10000, 20000, 29000].do {|testPos|
        var testLen = 5;
        var expected, actual, unicodeBefore;

        if(testPos + testLen < text.size, {
            expected = text[testPos..testPos+testLen-1];
            doc.selectRange(testPos, testLen);
            actual = doc.selectedString;
            unicodeBefore = unicodePositions.select {|p| p < testPos }.size;

            "pos %: unicode_before=%, expected='%', actual='%', match=%".format(
                testPos.asString.padLeft(5),
                unicodeBefore.asString.padLeft(3),
                expected,
                actual,
                expected == actual
            ).postln;
        });
    };
}, {
    "No non-ASCII bytes found - file is pure ASCII".postln;
});
"".postln;
)

// ==================== TEST 0.5c ====================
// Reverse engineer: select and find where we actually are
(
var doc = Document.current;
var text = doc.string;
var testPos = 29474;  // The position that failed
var selected, foundAt;

"".postln;
"=== TEST 0.5c: Where does selectRange(%) actually land? ===".format(testPos).postln;

doc.selectRange(testPos, 20);
selected = doc.selectedString;
"selectRange(%, 20) = '%'".format(testPos, selected).postln;

// Find this string in text
foundAt = text.find(selected);
"This string found in text at position: %".format(foundAt).postln;

if(foundAt.notNil, {
    "Offset: selectRange position % - actual position % = %".format(
        testPos, foundAt, testPos - foundAt
    ).postln;
});
"".postln;
)

// ==================== TEST 0.5d ====================
// Measure cumulative drift at multiple points
(
var doc = Document.current;
var text = doc.string;
var results = List.new;

"".postln;
"=== TEST 0.5d: Cumulative drift analysis ===".postln;
"pos      | selectRange gets | found_at | drift".postln;
"---------+------------------+----------+------".postln;

[100, 500, 1000, 2000, 3000, 5000, 7500, 10000, 15000, 20000, 25000, 29000].do {|testPos|
    var selected, foundAt, drift;

    if(testPos + 15 < text.size, {
        doc.selectRange(testPos, 15);
        selected = doc.selectedString;
        foundAt = text.find(selected);

        if(foundAt.notNil, {
            drift = testPos - foundAt;
            results.add([testPos, foundAt, drift]);
            "% | '%' | % | %".format(
                testPos.asString.padLeft(8),
                selected.asString.padRight(15)[0..14],
                foundAt.asString.padLeft(8),
                drift.asString.padLeft(5)
            ).postln;
        }, {
            "% | '%' | NOT FOUND".format(
                testPos.asString.padLeft(8),
                selected.asString.padRight(15)[0..14]
            ).postln;
        });
    });
};

"".postln;
// Analyze drift pattern
if(results.size > 1, {
    var drifts = results.collect {|r| r[2] };
    var driftDiffs = (1..drifts.size-1).collect {|i| drifts[i] - drifts[i-1] };
    "Drift values: %".format(drifts).postln;
    "Drift increments between samples: %".format(driftDiffs).postln;
});
"".postln;
)

// ==================== TEST 0.5e ====================
// Test if we can work backwards: find in string, then select
(
var doc = Document.current;
var text = doc.string;
var target = ".........";  // 9 dots - what we want to select
var stringPos, selected;

"".postln;
"=== TEST 0.5e: Find target in string, try to select it ===".postln;

// Find the dots in the CONTROLS section
stringPos = text.find("// ==================== CONTROLS ====================");
if(stringPos.notNil, {
    stringPos = text.find(target, false, stringPos);
});

if(stringPos.isNil, {
    "Could not find '%' in document".format(target).postln;
}, {
    "Found '%' at string position %".format(target, stringPos).postln;

    // What's the context around it?
    "Context: '%'".format(text[stringPos-20..stringPos+20]).postln;

    // If we select at that position, what do we get?
    doc.selectRange(stringPos, target.size);
    selected = doc.selectedString;
    "selectRange(%, %): '%'".format(stringPos, target.size, selected).postln;
    "Match: %".format(selected == target).postln;

    // Try adjusting by estimated drift (from 0.5d)
    // We'll need to look at 0.5d results first to know the drift
});
"".postln;
)

// ==================== TEST 0.5f ====================
// Character-by-character: where does drift start?
(
var doc = Document.current;
var text = doc.string;
var firstMismatch = nil;
var checkPoints = (0, 100 .. 1000) ++ (1000, 1500 .. 5000) ++ (5000, 7500 .. 30000);

"".postln;
"=== TEST 0.5f: Find where drift begins ===".postln;

checkPoints.do {|pos|
    var expected, actual;

    if(firstMismatch.isNil and: { pos + 1 < text.size }, {
        expected = text[pos..pos];
        doc.selectRange(pos, 1);
        actual = doc.selectedString;

        if(expected != actual, {
            firstMismatch = pos;
            "FIRST MISMATCH at position %".format(pos).postln;
            "  expected: '%' (ascii %)".format(expected, expected.ascii).postln;
            "  actual:   '%' (ascii %)".format(actual, actual.ascii).postln;

            // Look at surrounding area
            "  text around pos %: '%'".format(pos, text[pos-10..pos+10]).postln;
        });
    });
};

if(firstMismatch.isNil, {
    "No mismatch found in checked positions!".postln;
    "Checked up to position %".format(checkPoints.last).postln;
}, {
    "First mismatch at position %".format(firstMismatch).postln;

    // Detailed scan around first mismatch
    "".postln;
    "Detail scan around first mismatch:".postln;
    ((firstMismatch - 50).max(0) .. (firstMismatch + 50).min(text.size - 1)).do {|pos|
        var expected = text[pos..pos];
        var actual;
        doc.selectRange(pos, 1);
        actual = doc.selectedString;
        if(expected != actual, {
            "  pos %: expected '%' got '%'".format(pos, expected, actual).postln;
        });
    };
});
"".postln;
)

// ==================== TEST 0.5g ====================
// Document metadata check
(
var doc = Document.current;

"".postln;
"=== TEST 0.5g: Document metadata ===".postln;
"doc.class: %".format(doc.class).postln;
"doc.path: %".format(doc.path).postln;
"doc.title: %".format(doc.title).postln;
"doc.string.size: %".format(doc.string.size).postln;
"doc.text.size (if available): ".post;
try { doc.text.size.postln } { "N/A".postln };
"".postln;
)

// ============================================================
// MILESTONE 1: READ-ONLY INSPECTION
// ============================================================

// ==================== TEST 1.1 ====================
// Find a known string pattern
(
var doc = Document.current;
var text = doc.string;
var pattern = "~rev.(";
var pos = text.find(pattern);

"".postln;
"=== TEST 1.1: Find known string pattern ===".postln;

if(pos.isNil, {
    "FAIL: Could not find '%' in document".format(pattern).postln;
}, {
    "PASS: Found '%' at position %".format(pattern, pos).postln;
    "  context: '%'".format(text[pos..pos+30]).postln;
});
"".postln;
)

// ==================== TEST 1.2 ====================
// Find the dot string within a controller

(
var doc = Document.current;
var text = doc.string;
var controlsMarker = "// ==================== CONTROLS ====================";
var controlsStart = text.find(controlsMarker);
var controllerStart, searchRegion, quoteStart, quoteEnd, dots;

"".postln;
"=== TEST 1.2: Find dot string within controller ===".postln;

if(controlsStart.isNil, {
    "FAIL: CONTROLS marker not found".postln;
}, {
    // Search for ~rev.( AFTER the CONTROLS marker
    controllerStart = text.find("~rev.(", false, controlsStart);

    if(controllerStart.isNil, {
        "FAIL: controller not found after CONTROLS marker".postln;
    }, {
        // Look for the quoted string after the controller
        searchRegion = text[controllerStart..controllerStart+100];
        quoteStart = searchRegion.find("\"");
        quoteEnd = searchRegion.find("\"", false, quoteStart + 1);

        if(quoteStart.isNil or: quoteEnd.isNil, {
            "FAIL: Could not find quoted string".postln;
            "  searchRegion: '%'".format(searchRegion).postln;
        }, {
            dots = searchRegion[quoteStart+1..quoteEnd-1];
            "PASS: Found dots = '%' (% chars)".format(dots, dots.size).postln;
            "  absolute positions: % to %".format(
                controllerStart + quoteStart + 1,
                controllerStart + quoteEnd
            ).postln;
        });
    });
});
"".postln;
)

// ==================== TEST 1.3 ====================
// Parse ALL controllers into registry
(
var doc = Document.current;
var text = doc.string;
var controlsMarker = "// ==================== CONTROLS ====================";
var controlsStart = text.find(controlsMarker);
var controllers = [
    \rev, \fade, \speed, \jitter, \silence,
    \silenceDur, \override, \startPos, \startRange,
    \loopStart, \loopEnd
];
var registry = IdentityDictionary.new;
var foundCount = 0;

"".postln;
"=== TEST 1.3: Parse all controllers into registry ===".postln;

if(controlsStart.isNil, {
    "FAIL: CONTROLS marker not found".postln;
}, {
    "Searching after CONTROLS marker (position %)".format(controlsStart).postln;
    "".postln;

    controllers.do {|name|
        var pattern = "~" ++ name ++ ".(";
        var pos = text.find(pattern, false, controlsStart);  // search after CONTROLS
        var searchRegion, q1, q2, dots, absStart, absEnd;

        if(pos.notNil, {
            searchRegion = text[pos..pos+100];
            q1 = searchRegion.find("\"");
            q2 = searchRegion.find("\"", false, q1 + 1);

            if(q1.notNil and: q2.notNil, {
                absStart = pos + q1 + 1;
                absEnd = pos + q2;
                dots = text[absStart..absEnd-1];
                registry[name] = (
                    pattern: pattern,
                    dotStart: absStart,
                    dotEnd: absEnd,
                    currentDots: dots,
                );
                foundCount = foundCount + 1;
                "  %: found at %, dots='%' (%)".format(
                    name.asString.padRight(10),
                    absStart.asString.padLeft(5),
                    dots,
                    dots.size
                ).postln;
            }, {
                "  %: WARN - found pattern but no quotes".format(name).postln;
            });
        }, {
            "  %: not found".format(name).postln;
        });
    };

    "".postln;
    "Registry built with %/% entries".format(foundCount, controllers.size).postln;

    if(foundCount >= 5, {
        "PASS: Found at least 5 controllers".postln;
    }, {
        "FAIL: Only found % controllers".format(foundCount).postln;
    });

    // Save for subsequent tests
    ~visualRegistry = registry;
    "Saved to ~visualRegistry for Test 1.4".postln;
});
"".postln;
)

// ==================== TEST 1.4 ====================
// Verify positions with selectRange - handle unicode offset
(
var doc = Document.current;
var text = doc.string;
var registry = ~visualRegistry;
var testController = \rev;
var info, len, directExtract;
var charToBytePos, byteStart, byteLen;

// Convert character position to byte position
// selectRange uses byte offsets, string indexing uses char offsets
charToBytePos = {|str, charPos|
    var bytes = 0;
    charPos.do {|i|
        var char = str[i];
        var code = char.ascii;
        // UTF-8: ASCII < 128 = 1 byte, otherwise estimate from codepoint
        // Simple heuristic: non-ASCII chars are likely 2-3 bytes
        if(code < 128, { bytes = bytes + 1 }, {
            // For chars like → (U+2192), UTF-8 uses 3 bytes
            // This is a simplification - proper UTF-8 encoding is complex
            if(code < 2048, { bytes = bytes + 2 }, { bytes = bytes + 3 });
        });
    };
    bytes;
};

"".postln;
"=== TEST 1.4: Verify positions with selectRange ===".postln;

if(registry.isNil, {
    "SKIP: Run Test 1.3 first to build registry".postln;
}, {
    info = registry[testController];
    if(info.isNil, {
        "FAIL: % not in registry".format(testController).postln;
    }, {
        len = info.dotEnd - info.dotStart;

        "Controller: %".format(testController).postln;
        "  char positions: % to % (% chars)".format(info.dotStart, info.dotEnd, len).postln;

        // Direct string extraction (works)
        directExtract = text[info.dotStart..info.dotEnd-1];
        "  direct extract: '%'".format(directExtract).postln;

        // Convert to byte positions
        byteStart = charToBytePos.(text, info.dotStart);
        byteLen = charToBytePos.(text, info.dotEnd) - byteStart;
        "  byte positions: % to % (% bytes)".format(byteStart, byteStart + byteLen, byteLen).postln;

        // Try with byte positions
        doc.selectRange(byteStart, byteLen);
        "  selectRange(byte) result: '%'".format(doc.selectedString).postln;

        if(doc.selectedString == info.currentDots, {
            "PASS: Byte-position selection works!".postln;
        }, {
            "FAIL: Still mismatched. Need different approach.".postln;
        });
    });
});
"".postln;
)

// ==================== TEST 1.4b ====================
// Verify ALL controller positions
(
var doc = Document.current;
var registry = ~visualRegistry;
var passCount = 0, failCount = 0;

"".postln;
"=== TEST 1.4b: Verify ALL controller positions ===".postln;

if(registry.isNil, {
    "SKIP: Run Test 1.3 first".postln;
}, {
    registry.keysValuesDo {|name, info|
        doc.selectRange(info.dotStart, info.dotEnd - info.dotStart);

        if(doc.selectedString == info.currentDots, {
            "  %: PASS".format(name.asString.padRight(10)).postln;
            passCount = passCount + 1;
        }, {
            "  %: FAIL - expected '%', got '%'".format(
                name, info.currentDots, doc.selectedString
            ).postln;
            failCount = failCount + 1;
        });
    };

    "".postln;
    "Results: % passed, % failed".format(passCount, failCount).postln;

    if(failCount == 0, {
        "PASS: All positions verified".postln;
    }, {
        "FAIL: % positions incorrect".format(failCount).postln;
    });
});
"".postln;
)

// ==================== BONUS: Find control region markers ====================
(
var doc = Document.current;
var text = doc.string;
var startMarker = "// ==================== CONTROLS ====================";
var endMarker = "// ==================== ADJUSTMENTS ====================";
var startPos = text.find(startMarker);
var endPos = text.find(endMarker);

"".postln;
"=== BONUS: Control region markers ===".postln;

if(startPos.notNil, {
    "CONTROLS marker at position %".format(startPos).postln;
}, {
    "CONTROLS marker not found".postln;
});

if(endPos.notNil, {
    "ADJUSTMENTS marker at position %".format(endPos).postln;
}, {
    "ADJUSTMENTS marker not found".postln;
});

if(startPos.notNil and: endPos.notNil, {
    "Control region: % to % (% chars)".format(startPos, endPos, endPos - startPos).postln;
});
"".postln;
)

// ==================== SUMMARY ====================
(
"".postln;
"=== MILESTONE 1 SUMMARY ===".postln;
"".postln;
"| Test | Description | Status |".postln;
"|------|-------------|--------|".postln;
"| 1.1 | Find known string pattern | ____ |".postln;
"| 1.2 | Find dot string within controller | ____ |".postln;
"| 1.3 | Parse all controllers into registry | ____ |".postln;
"| 1.4 | Verify positions with selectRange | ____ |".postln;
"".postln;
"EXIT CRITERIA:".postln;
"  - Can find all target controllers".postln;
"  - Position values are accurate (verified by selection)".postln;
"  - No document modifications occurred".postln;
"".postln;
)
