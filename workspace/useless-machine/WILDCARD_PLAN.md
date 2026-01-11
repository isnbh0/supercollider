# WILDCARD: Autonomous Chaos Engine for soundtest.scd

## Overview

A background SuperCollider routine that simulates an "evil bug" taking control of the performance. It randomly mutates environment variables in `soundtest.scd`, producing dramatic musical changes while maintaining theatrical showmanship through elaborate post window messaging.

---

## Research Sources

- [SuperCollider Environment System](https://doc.sccode.org/Classes/Environment.html) - `~var` syntax is shorthand for `currentEnvironment.at/put`
- [Routines and Tasks](https://doc.sccode.org/Tutorials/Getting-Started/15-Sequencing-with-Routines-and-Tasks.html) - Using `fork` and `inf.do` for background processes
- [Post Class](https://doc.sccode.org/Classes/Post.html) - Stream-based posting for theatrical output
- [JITLib](https://doc.sccode.org/Overviews/JITLib.html) - Runtime modification patterns

---

## Architecture

### Core Concept: The Mutation Registry

Instead of parsing code, we define a **whitelist of mutable targets** with their ranges and musical impact. The wildcard routine picks from this registry and applies mutations directly to environment variables.

```
┌─────────────────────────────────────────────────────────────────┐
│  WILDCARD ENGINE                                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  REGISTRY   │───▶│  SELECTOR   │───▶│  MUTATOR    │         │
│  │  (targets)  │    │  (weighted) │    │  (apply)    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    POST WINDOW                              ││
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ││
│  │  ▓▓▓   W I L D C A R D   A C T I V E   ▓▓▓                  ││
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Strategy 1: Focused Mutation Targets

The wildcard focuses on **four high-impact musical dimensions**:

### 1. STUTTER GENERATION (probability + short duration)

Push generators toward high-probability, micro-duration stutter:

```supercollider
~wildcardStutter = {
    // Pick a generator (0-3)
    var gen = 4.rand;
    var spec = ~genSpecs[gen];

    // Stutter = high prob + short dur
    spec[0] = rrand(0.5, 1.0);       // probability: 50-100%
    spec[1] = rrand(0.005, 0.05);    // duration: 5-50ms (stutter range)
    spec[2] = rrand(0.3, 0.7);       // keep amp moderate

    ~genSpecs[gen] = spec;

    "▸▸▸ STUTTER INJECTED: gen% prob=% dur=%ms".format(
        gen, spec[0].round(0.01), (spec[1]*1000).round(0.1)
    ).postln;
};
```

### 2. JITTER (start point chaos)

Increase standard deviation of sample start positions:

```supercollider
~wildcardJitter = {
    var oldJitter = ~playheadJitter;
    var newJitter = rrand(0.1, 0.5);  // 10-50% of sample length

    ~playheadJitter = newJitter;

    "▸▸▸ JITTER SPIKE: % → %".format(
        oldJitter.round(0.01), newJitter.round(0.01)
    ).postln;
};
```

### 3. SAMPLE SWITCHING

Randomly swap to different samples from the pack:

```supercollider
~wildcardSample = {
    var oldIdx = ~samplePack.indexOf(~genSample);
    var newIdx = (~samplePack.size).rand;

    // Exclude current sample
    while { newIdx == oldIdx } { newIdx = (~samplePack.size).rand };

    ~genSample = ~samplePack[newIdx];

    "".postln;
    "╔════════════════════════════════════╗".postln;
    "║   S A M P L E   S W I T C H        ║".postln;
    ("║   " ++ oldIdx ++ " ──▶ " ++ newIdx).postln;
    "╚════════════════════════════════════╝".postln;
};
```

### 4. HIGH-IMPACT SOUND EVENTS

Sudden start/stop of dramatic sounds:

```supercollider
~wildcardImpact = {
    // Options: loud burst, sudden silence, drone spawn, full-sample play
    var action = [\burst, \silence, \drone, \fullSample].choose;

    switch(action,
        \burst, {
            // Loud short burst on all generators
            4.do {|i|
                ~trigGen.(i, 1.0.rand);
            };
            "".postln;
            "████ BURST ████".postln;
        },
        \silence, {
            // Kill all generators
            4.do {|i| ~haltGen.(i) };
            "".postln;
            "░░░░ SILENCE ░░░░".postln;
        },
        \drone, {
            // Long duration generator
            var gen = 4.rand;
            ~genSpecs[gen] = [1.0, rrand(5, 15), 0.4];  // 100% prob, 5-15s dur
            ~trigGen.(gen);
            "".postln;
            "≈≈≈≈ DRONE SPAWNED ≈≈≈≈".postln;
        },
        \fullSample, {
            // Play the entire loop region at full volume
            ~listenLoop.();
            "".postln;
            "▶▶▶▶ FULL SAMPLE ◀◀◀◀".postln;
        }
    );
};
```

### Mutation Probability Weights

```supercollider
~wildcardActions = [
    [~wildcardStutter, 0.4],   // 40% - most common
    [~wildcardJitter, 0.25],   // 25%
    [~wildcardSample, 0.15],   // 15% - less frequent, more dramatic
    [~wildcardImpact, 0.2],    // 20% - punctuation events
];

~wildcardMutate = {
    var roll = 1.0.rand;
    var cumulative = 0;

    ~wildcardActions.do {|pair|
        cumulative = cumulative + pair[1];
        if(roll < cumulative, {
            pair[0].();
            ^nil;  // exit after first match
        });
    };
};
```

---

## Strategy 2: Chaos Levels (Controllability)

Escalating levels control **which actions are available** and **how aggressive** they are:

```supercollider
~wildcardLevel = 1;  // 1-5

~chaosLevels = [
    // Level 1: SUBTLE - jitter only, mild values
    (
        name: "SUBTLE",
        interval: [5, 10],           // 5-10 sec between mutations
        actions: [\jitter],
        jitterRange: [0.05, 0.15],   // mild jitter
        stutterDurRange: [0.03, 0.1], // longer stutters
        stutterProbRange: [0.2, 0.4],
        impactActions: [\silence],   // only silence, no bursts
    ),

    // Level 2: NOTICEABLE - add stutter
    (
        name: "NOTICEABLE",
        interval: [3, 6],
        actions: [\jitter, \stutter],
        jitterRange: [0.1, 0.25],
        stutterDurRange: [0.02, 0.08],
        stutterProbRange: [0.3, 0.6],
        impactActions: [\silence],
    ),

    // Level 3: DISRUPTIVE - add sample switching
    (
        name: "DISRUPTIVE",
        interval: [2, 4],
        actions: [\jitter, \stutter, \sample],
        jitterRange: [0.15, 0.35],
        stutterDurRange: [0.01, 0.05],
        stutterProbRange: [0.5, 0.8],
        impactActions: [\silence, \drone],
    ),

    // Level 4: CHAOTIC - add impacts
    (
        name: "CHAOTIC",
        interval: [1, 3],
        actions: [\jitter, \stutter, \sample, \impact],
        jitterRange: [0.2, 0.5],
        stutterDurRange: [0.005, 0.03],
        stutterProbRange: [0.7, 1.0],
        impactActions: [\silence, \drone, \burst],
    ),

    // Level 5: TOTAL CHAOS - everything, aggressive
    (
        name: "TOTAL CHAOS",
        interval: [0.3, 1.5],
        actions: [\jitter, \stutter, \sample, \impact],
        jitterRange: [0.3, 0.8],
        stutterDurRange: [0.002, 0.02],   // micro-stutters
        stutterProbRange: [0.9, 1.0],
        impactActions: [\silence, \drone, \burst, \fullSample],
    ),
];

~wildcardSetLevel = {|level|
    ~wildcardLevel = level.clip(1, 5);
    var config = ~chaosLevels[~wildcardLevel - 1];

    "".postln;
    "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓".postln;
    ("┃  CHAOS LEVEL: " ++ ~wildcardLevel ++ " - " ++ config.name).postln;
    "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛".postln;
};
```

---

## Strategy 3: Theatrical Post Window

### ASCII Art Banners

```supercollider
~wildcardBanners = [
    // Awakening
    "
    ╔══════════════════════════════════════════╗
    ║  ░░░ W I L D C A R D   A W A K E S ░░░   ║
    ║         something stirs...               ║
    ╚══════════════════════════════════════════╝
    ",

    // Level up
    "
    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ▓   C H A O S   L E V E L   U P   ▓▓▓▓▓▓▓▓
    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ",

    // Mutation announcement
    "
    ┌──────────────────────────────────────────┐
    │  ▸▸▸ MUTATION DETECTED ◂◂◂               │
    └──────────────────────────────────────────┘
    ",

    // Coda warning
    "
    ████████████████████████████████████████████
    █                                          █
    █   ⚠️  CRITICAL INSTABILITY DETECTED  ⚠️   █
    █       SYSTEM INTEGRITY: FAILING          █
    █                                          █
    ████████████████████████████████████████████
    ",

    // Final collapse
    "
    ▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄

         T̷̨̛̖͇͓̲̪̮̳̈́̈́̅͛O̶̡̧̺̝̲̙͕͂̌͗̕T̵̳̹͔̼̞̏͆̕A̷̡̘̙̱̤̓̂̔͜L̴̨̛̲̪̱͙͓̈́̄͝
         C̵̨̛̮̱͓̝̝̾̿̔͝O̴̧̡̱͖̙͓̽̓̿̑͜L̶̢̛̪̺̲̭̙̓̽̓L̴̨̛̪̱̺͓̝̿̾̔A̵̧̡̱͖̙͓̽̓̿͜P̴̧̛̪̺̲̭̙̓̽͝S̶̢̛̮̱͓̝̾̿̔Ę̴̛̲̪̱͙͓̈́̄

    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
    "
];
```

### Mutation Log Format

Each mutation should be announced with flair:

```supercollider
~logMutation = {|target, oldVal, newVal, impact|
    var impactBar = "█" ! impact ++ "░" ! (5 - impact);
    var direction = if(newVal > oldVal, "▲", "▼");

    "".postln;
    "┌─ MUTATION ─────────────────────────────".postln;
    ("│  TARGET:  " ++ target).postln;
    ("│  " ++ oldVal.round(0.001) ++ " " ++ direction ++ " " ++ newVal.round(0.001)).postln;
    ("│  IMPACT:  [" ++ impactBar.join ++ "]").postln;
    "└─────────────────────────────────────────".postln;
};
```

---

## Strategy 4: Markers in soundtest.scd

Add special comments that document mutable values (for human reference, not parsing):

```supercollider
// In ~prep function of soundtest.scd:

// @wildcard: tickRate [1, 200] timing
~tickRate = 40;

// @wildcard: playheadSpeedPct [0, 500] timing
~playheadSpeedPct = 100;

// @wildcard: silenceProb [0, 1] prob
~silenceProb = 0.0;

// @wildcard: masterLevel [0, 2] amp
~masterLevel = 0.8;

// @wildcard: genSpecs[*][0] [0, 1] generator - probability per generator
// @wildcard: genSpecs[*][1] [0.001, 10] generator - duration per generator
// @wildcard: genSpecs[*][2] [0, 1] generator - amplitude per generator
~genSpecs = [
    [0.3,   0.01,  0.7],   // id 0
    [0.2,   0.1,   0.5],   // id 1
    [0.08,  1.0,   0.4],   // id 2
    [0.01,  10.0,  0.25],  // id 3
];
```

These markers serve as documentation and make it clear which values are "fair game" for the wildcard system.

---

## Strategy 5: The Coda (7-Minute Apocalypse)

### Timeline

```
Time        Chaos Level    Behavior
─────────────────────────────────────────────────────
0:00-1:00   Level 1        Gentle. Occasional amp/reverb tweaks.
1:00-2:30   Level 2        Probability mutations. Random silences.
2:30-4:00   Level 3        Texture chaos. Jitter increases.
4:00-5:30   Level 4        Timing mutations. tickRate fluctuates.
5:30-6:30   Level 5        TOTAL CHAOS. All parameters volatile.
6:30-7:00   CODA           Exponential acceleration to crash.
```

### Coda Implementation

```supercollider
~wildcardCoda = {
    var codaDuration = 30;  // 30 seconds of escalation
    var startTime = Main.elapsedTime;

    "".postln;
    ~wildcardBanners[3].postln;  // CRITICAL INSTABILITY
    "CODA INITIATED - 30 SECONDS TO COLLAPSE".postln;
    "".postln;

    {
        var elapsed, progress, interval, mutations;

        inf.do {|i|
            elapsed = Main.elapsedTime - startTime;
            progress = (elapsed / codaDuration).clip(0, 1);

            // Interval shrinks exponentially: 1s → 0.01s
            interval = 1 * (0.01 ** progress);

            // Mutations per tick increases: 1 → 10
            mutations = (1 + (9 * progress)).asInteger;

            // Memory pressure: create arrays that won't be GC'd fast enough
            if(progress > 0.7, {
                ~wildcardGarbage = ~wildcardGarbage.add(Array.fill(10000, { 1.0.rand }));
            });

            // Extreme mutations
            mutations.do {
                var target = ~wildcardTargets.choose;
                var range = target[2] - target[1];
                var mutation = target[1] + (range * 1.0.rand);
                currentEnvironment[target[0]] = mutation;

                // Glitchy posts
                if(0.3.coin, {
                    ("▓▓▓ " ++ target[0] ++ " → " ++ mutation.round(0.001) ++ " ▓▓▓").postln;
                });
            };

            // Progress bar
            if(i % 10 == 0, {
                var bar = "█" ! (progress * 30).asInteger ++ "░" ! (30 - (progress * 30).asInteger);
                ("COLLAPSE: [" ++ bar.join ++ "] " ++ (progress * 100).asInteger ++ "%").postln;
            });

            // Final moments
            if(progress > 0.95, {
                ~wildcardBanners[4].postln;  // TOTAL COLLAPSE
                // Force memory error
                inf.do { ~wildcardGarbage = ~wildcardGarbage.add(Array.fill(100000, { 1.0.rand })) };
            });

            interval.wait;
        };
    }.fork;
};
```

### Alternative Crash Methods

1. **Memory Exhaustion** (shown above): Continuously allocate arrays
2. **Infinite Loop**: Remove all `.wait` calls to freeze SC
3. **Server Overload**: Spawn thousands of synths
4. **Feedback Loop**: Route output to input with gain > 1

```supercollider
// Server overload option
~codaCrash_synths = {
    1000.do {|i|
        Synth(\gen_sampler, [
            \sample, ~genSample,
            \start, 1.0.rand,
            \dur, 10,
            \amp, 0.1,
        ]);
        ("SYNTH " ++ i ++ " SPAWNED").postln;
    };
};

// Feedback option (DANGEROUS - use limiter!)
~codaCrash_feedback = {
    {
        var fb = LocalIn.ar(2);
        var sig = In.ar(0, 2) + (fb * 1.1);  // gain > 1 = exponential growth
        LocalOut.ar(sig);
        sig;
    }.play;
};
```

---

## Refactoring soundtest.scd

The current architecture of `soundtest.scd` needs modifications to work smoothly with the wildcard system.

### Current Issues

1. **Generator specs are copied, not referenced** - When `~genSpecs[i]` is read, it returns a copy. Mutations might not affect running behavior.

2. **No centralized sample registry** - Sample switching needs access to metadata (name, duration, characteristics).

3. **Impact functions are internal** - `~trigGen`, `~haltGen`, `~listenLoop` work but need consistent interfaces for wildcard.

4. **Missing reset capability** - No way to snapshot/restore state for rehearsal recovery.

### Required Changes

#### 1. Make genSpecs reactive

Instead of checking `~genSpecs[id][0].coin` once per tick, allow wildcard to affect behavior mid-tick:

```supercollider
// BEFORE (in ~start tick loop):
var prob = ~genSpecs[id][0];
if(prob.coin, { ~tryTrigGen.(id) });

// AFTER - check at trigger time, not loop start:
~getGenProb = {|id| ~genSpecs[id][0] };
~getGenDur = {|id| ~genSpecs[id][1] };
~getGenAmp = {|id| ~genSpecs[id][2] };

// In tick loop:
if(~getGenProb.(id).coin, { ~tryTrigGen.(id) });

// In ~trigGen:
~genSynths[id] = Synth(\gen_sampler, [
    \dur, ~getGenDur.(id),  // read at trigger time
    \amp, ~getGenAmp.(id),
    // ...
]);
```

#### 2. Sample registry with metadata

```supercollider
// Add to ~boot after loading samples:
~sampleRegistry = ~samplePack.collect {|buf, i|
    (
        buffer: buf,
        index: i,
        name: PathName(buf.path).fileNameWithoutExtension,
        duration: buf.duration,
        channels: buf.numChannels,
    )
};

// Wildcard can then announce:
~wildcardSample = {
    var oldInfo = ~sampleRegistry.detect {|s| s.buffer == ~genSample };
    var newInfo = ~sampleRegistry.choose;

    ~genSample = newInfo.buffer;

    "SAMPLE: % → %".format(oldInfo.name, newInfo.name).postln;
};
```

#### 3. Expose impact functions at top level

Ensure these are defined in `~prep` and accessible:

```supercollider
// Already exists, but verify these work when called from wildcard:
~trigGen.(id, startOverride)   // trigger generator id
~haltGen.(id)                  // stop generator id
~listenLoop.()                 // play full loop region

// Add burst helper:
~burstAll = {|amp = 0.5|
    4.do {|i|
        ~trigGen.(i, 1.0.rand);
    };
};

// Add silence helper:
~silenceAll = {
    4.do {|i| ~haltGen.(i) };
};
```

#### 4. State snapshot/restore

```supercollider
// Add to ~prep:
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
    );
    "State snapshot saved".postln;
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
        "State restored".postln;
    }, {
        "No saved state".postln;
    });
};
```

#### 5. Wildcard integration hook

Add a hook that wildcard.scd can call to verify soundtest is ready:

```supercollider
// At end of ~prep:
~soundtestReady = true;
~soundtestVersion = "1.1";  // bump when interface changes

// Wildcard checks:
~wildcardVerify = {
    if(~soundtestReady != true, {
        "ERROR: soundtest not ready - run ~prep.() first".postln;
        ^false;
    });
    if(~samplePack.isNil or: { ~samplePack.size == 0 }, {
        "ERROR: no samples loaded - run ~boot.() first".postln;
        ^false;
    });
    true;
};
```

### Markers to Add

Add these comments to soundtest.scd for documentation (not parsing):

```supercollider
// === WILDCARD TARGETS ===
// The following variables can be mutated by wildcard.scd:
//
// @wildcard STUTTER:
//   ~genSpecs[0..3][0] - probability (0-1)
//   ~genSpecs[0..3][1] - duration (0.001-10 sec)
//   ~genSpecs[0..3][2] - amplitude (0-1)
//
// @wildcard JITTER:
//   ~playheadJitter - start position std dev (0-1)
//
// @wildcard SAMPLE:
//   ~genSample - current buffer from ~samplePack
//
// @wildcard IMPACT:
//   ~trigGen.(id) - trigger generator
//   ~haltGen.(id) - stop generator
//   ~listenLoop.() - play full sample
//   ~burstAll.() - trigger all generators
//   ~silenceAll.() - stop all generators
```

---

## Implementation Plan

### Phase 1: Refactor soundtest.scd

1. Add getter functions for genSpecs (`~getGenProb`, `~getGenDur`, `~getGenAmp`)
2. Create `~sampleRegistry` with metadata
3. Add `~burstAll` and `~silenceAll` helpers
4. Implement `~stateSnapshot` and `~stateRestore`
5. Add `~soundtestReady` verification flag
6. Add `// @wildcard` documentation block

### Phase 2: Core Engine (wildcard.scd)

1. Define chaos level configs
2. Implement mutation actions (`~wildcardStutter`, `~wildcardJitter`, etc.)
3. Implement `~wildcardRoutine` main loop
4. Add control functions: `~wildcardStart`, `~wildcardStop`, `~wildcardSetLevel`
5. Implement `~wildcardVerify` safety check

### Phase 3: Theatrical Elements

1. Create ASCII art banners dictionary
2. Implement level-up announcements with dramatic timing
3. Add mutation logging with visual flair (impact bars, arrows)
4. Create "heartbeat" status indicator (optional pulse in post window)

### Phase 4: Coda System

1. Implement `~wildcardCoda` escalation routine
2. Test crash methods (memory, synths, feedback)
3. Add visual countdown/progress
4. Create recovery mechanism for rehearsal (`~wildcardRecover`)

---

## Control Interface

```supercollider
// === WILDCARD CONTROLS ===

// Lifecycle
~wildcardStart.();           // Begin chaos (auto-snapshots state first)
~wildcardStop.();            // Stop chaos (immediate)
~wildcardPause.();           // Pause (resume later)
~wildcardResume.();          // Resume from pause

// Chaos level (1-5)
~wildcardSetLevel.(1);       // SUBTLE - jitter only
~wildcardSetLevel.(2);       // NOTICEABLE - add stutter
~wildcardSetLevel.(3);       // DISRUPTIVE - add sample switching
~wildcardSetLevel.(4);       // CHAOTIC - add impacts
~wildcardSetLevel.(5);       // TOTAL CHAOS

// Coda (final 30-sec collapse)
~wildcardCoda.();            // Trigger final collapse → crash

// Recovery (for rehearsal)
~stateSnapshot.();           // Save current state (run before wildcard)
~stateRestore.();            // Restore saved state
~wildcardRecover.();         // Emergency: stop + restore

// Status
~wildcardStatus.();          // Show current level, running state, mutation count

// Manual triggers (for testing)
~wildcardStutter.();         // Force stutter mutation
~wildcardJitter.();          // Force jitter mutation
~wildcardSample.();          // Force sample switch
~wildcardImpact.();          // Force impact event
```

---

## Safety Features

1. **Kill Switch**: `~wildcardStop` immediately halts all mutations
2. **State Snapshots**: `~stateSnapshot` saves all mutable values before chaos begins
3. **Recovery Mode**: `~stateRestore` restores saved state (soundtest.scd)
4. **Emergency Recovery**: `~wildcardRecover` = stop + restore in one call
5. **Verification**: `~wildcardVerify` checks that soundtest is ready before starting
6. **Rate Limiting**: Minimum 0.1s between mutations (prevent language freeze)

```supercollider
~wildcardRecover = {
    // Stop the chaos routine
    ~wildcardStop.();

    // Restore state (uses soundtest's ~stateRestore)
    ~stateRestore.();

    // Theatrical announcement
    "".postln;
    "╔════════════════════════════════════════════╗".postln;
    "║                                            ║".postln;
    "║   ░░░ S Y S T E M   R E C O V E R E D ░░░  ║".postln;
    "║         chaos contained...for now          ║".postln;
    "║                                            ║".postln;
    "╚════════════════════════════════════════════╝".postln;
};
```

---

## File Structure

```
projects/glitch-workshop/
├── soundtest.scd          # Main performance file (with @wildcard markers)
├── wildcard.scd           # Chaos engine
├── glitch-loader.scd      # Sample loading
└── WILDCARD_PLAN.md       # This document
```

---

## Testing Checklist

### Phase 1: soundtest.scd refactoring
- [ ] `~getGenProb`, `~getGenDur`, `~getGenAmp` work correctly
- [ ] `~sampleRegistry` populates with metadata
- [ ] `~burstAll` triggers all 4 generators
- [ ] `~silenceAll` stops all generators
- [ ] `~stateSnapshot` / `~stateRestore` round-trips correctly

### Phase 2: wildcard.scd core
- [ ] `~wildcardVerify` fails gracefully if soundtest not ready
- [ ] `~wildcardStart` / `~wildcardStop` lifecycle works
- [ ] Chaos levels limit available actions correctly
- [ ] Mutation timing follows level config intervals

### Phase 3: Mutations
- [ ] `~wildcardStutter` changes genSpecs probability and duration
- [ ] `~wildcardJitter` changes playheadJitter
- [ ] `~wildcardSample` switches samples and posts name
- [ ] `~wildcardImpact` triggers burst/silence/drone/fullSample

### Phase 4: Theatrical
- [ ] ASCII banners display correctly in post window
- [ ] Level-up announcements are dramatic
- [ ] Mutation logs show target, old→new, impact bar

### Phase 5: Coda
- [ ] 7-minute escalation timeline works
- [ ] Final 30-second collapse accelerates properly
- [ ] Crash method triggers reliably (memory/synths/feedback)
- [ ] `~wildcardRecover` works after crash (requires server reboot)

### Integration
- [ ] Full 7-minute performance runs without premature crash
- [ ] Post window remains readable throughout
- [ ] Audio changes are musically dramatic, not just noise
