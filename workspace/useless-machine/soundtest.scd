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
    s.sync;

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

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>> RUN HERE!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
( ~boot.(); )
( ~prep.(); )
( ~start.(); )
( ~stop.(); )


~initialized = nil;
(Document.current.dir ++ "/wildcard.scd").load;
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>> FULL PERFORMANCE START!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// ONE BUTTON TO START EVERYTHING - 7 minute auto-escalation:
//   0:00 - 1:00  Level 1 (subtle)
//   1:00 - 2:30  Level 2 (noticeable)
//   2:30 - 4:00  Level 3 (disruptive)
//   4:00 - 5:30  Level 4 (chaotic)
//   5:30 - 6:30  Level 5 (total chaos)
//   6:30 - 7:00  CODA (collapse + crash)
(
~performanceStart = {
    var wildcardOk;

    // Guard: ensure system is ready
    if(~soundtestReady != true, {
        "오류: ~boot.() 와 ~prep.() 먼저 실행하세요".postln;
        "Error: Run ~boot.() and ~prep.() first".postln;
        ^nil;
    });

    // Stop any existing escalation routine to prevent orphaned routines
    if(~escalationRoutine.notNil, {
        "Stopping previous escalation routine...".postln;
        ~escalationRoutine.stop;
        ~escalationRoutine = nil;
    });

    // Load wildcard if not loaded
    (Document.current.dir ++ "/wildcard.scd").load;

    // Start playback
    ~start.();

    // Save state before chaos
    ~stateSnapshot.();

    // Start wildcard at level 1 and check if it succeeded
    wildcardOk = ~wildcardStart.();
    if(wildcardOk.isNil, {
        "WARNING: Wildcard failed to start - check ~boot and ~prep".postln;
        "Performance continuing without wildcard automation".postln;
    });

    // Auto-escalation routine
    ~escalationRoutine = {
        "PERFORMANCE STARTED - 7 minute arc".postln;
        "Level 1: SUBTLE".postln;

        60.wait;  // 1:00 - Level 2
        ~wildcardSetLevel.(2);

        90.wait;  // 2:30 - Level 3
        ~wildcardSetLevel.(3);

        90.wait;  // 4:00 - Level 4
        ~wildcardSetLevel.(4);

        90.wait;  // 5:30 - Level 5
        ~wildcardSetLevel.(5);

        60.wait;  // 6:30 - CODA
        ~wildcardCoda.();

        // Wait for coda to complete (30 seconds) before declaring done
        30.wait;

        "".postln;
        "================================================".postln;
        "   PERFORMANCE COMPLETE / 공연 종료             ".postln;
        "================================================".postln;
        "".postln;

        // Clean up
        ~escalationRoutine = nil;
    }.fork;

    "=== PERFORMANCE MODE STARTED ===";
};
)

// RUN THIS TO START THE FULL 7-MINUTE PERFORMANCE:
( ~performanceStart.(); )

// STOP THE ESCALATION TIMER (keeps sound running, stops auto-level-up):
( if(~escalationRoutine.notNil, { ~escalationRoutine.stop }); "Escalation stopped"; )


// ==================== CONTROLS ====================

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>> WILDCARD HERE!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
( (Document.current.dir ++ "/wildcard.scd").load; )  // LOAD WILDCARD
( ~wildcardStart.(); )      // START CHAOS
( ~wildcardStop.(); )       // STOP CHAOS
( ~wildcardSetLevel.(1); )  // LEVEL 1 = subtle
( ~wildcardSetLevel.(2); )  // LEVEL 2 = noticeable
( ~wildcardSetLevel.(3); )  // LEVEL 3 = disruptive
( ~wildcardSetLevel.(4); )  // LEVEL 4 = chaotic
( ~wildcardSetLevel.(5); )  // LEVEL 5 = total chaos
( ~wildcardCoda.(); )       // FINAL 30-SEC COLLAPSE!!!

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>> SAMPLE HERE!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
~genSample = ~samplePack[0];   // Amen break
~genSample = ~samplePack[4];   // Piano
~genSample = ~samplePack[6];   // First Class Piano (DEFAULT)

// Random sample
( ~randomSample.() ; )

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

// Loop points: constrain playback to a portion of the sample
~getLoop.();  // show current loop points
~setLoop.(0.0, 0.1);  // set both start and end
~setLoopStart.(0.0);  // just start
~setLoopEnd.(1.0);    // just end
~resetLoop.();        // reset to full sample

( ~loopStart.(  // loop start: 0 → 1 (init: 0)
    ""
))

( ~loopEnd.(  // loop end: 0 → 1 (init: 1)
    "........."
))

// Presets
~preset.(\original);
~preset.(\normal);
~preset.(\ambient);
~preset.(\stutter);

// Original playback (seamless, like the actual sample)
~originalMode.();      // configure for seamless playback (enables seamlessMode)
~glitchMode.();        // return to normal glitchy mode
~listenLoop.();        // play loop region once (true original, no tick system)

// Debug mode
~debug = true;         // enable debug output
~debug = false;        // disable debug output
~debugInterval = 10;   // print every N ticks (lower = more output)
~calcOriginalDur.(true);  // verbose calculation breakdown

// Manual seamless control
~seamlessMode = true;  // synths overlap (for original playback)
~seamlessMode = false; // synths halted before new trigger (for glitch)
~getSampleDur.();      // show sample duration in seconds
~calcOriginalDur.();   // show calculated duration per tick

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
~setLoop.(0.0, 0.9);       // set start/end
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
    ""
))


// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>> PANIC BUTTON!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

// PANIC LEVEL 1: Stop everything gracefully
(
    ~stop.();
    ~wildcardStop.();
    "PANIC 1: Stopped playback and wildcard";
)

// PANIC LEVEL 2: Stop + restore saved state
(
    ~stop.();
    ~wildcardStop.();
    ~stateRestore.();
    ~start.();
    "PANIC 2: Restored and restarted";
)

// PANIC LEVEL 3: Full wildcard recovery
(
    ~wildcardRecover.();
    ~stop.();
    ~start.();
    "PANIC 3: Full wildcard recovery";
)

// PANIC LEVEL 4: NUCLEAR - full reboot (run each line separately!)
// Step 1: Cmd+. (stop all sound in SuperCollider)
// Step 2:
( ~boot.(); )
// Step 3:
( ~prep.(); )
// Step 4:
( ~start.(); )

// INSTANT SILENCE (run this if sound is out of control)
( s.freeAll; "ALL SYNTHS KILLED"; )

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
