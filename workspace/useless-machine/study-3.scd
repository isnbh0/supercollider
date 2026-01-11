(
    s.quit;
    s.boot;
)


// formatting examples
(
    {
        SinOsc.ar(
            freq: 440,
            phase: 0,
            mul: 0.2
        )
    }.play;
)

// now here's an equivalent SynthDef
(
    SynthDef.new(
        name: "tutorial-SinOsc",
        ugenGraphFunc: {
            |out|
            Out.ar(
                bus: out,
                channelsArray: SinOsc.ar(
                    freq: 440,
                    phase: 0,
                    mul: 0.2
                )
            )
        }
    ).play;
)

// ============================

// pan2

// hear the difference, LinPan having a slight drop in the middle...
{ LinPan2.ar(SinOsc.ar(440), Line.kr(-1, 1, 5)) }.play

// ... whereas Pan2 is more smooth
{ Pan2.ar(SinOsc.ar(440), Line.kr(-1, 1, 5)) }.play

// other examples
{ Pan2.ar(PinkNoise.ar(0.4), FSinOsc.kr(2), 0.3) }.play;


// Impulse
s.scope.window.alwaysOnTop_(true);
{ Impulse.ar(400, 0.0, 0.5, 0) }.play

{ Impulse.ar(XLine.kr(800, 100, 5), 0.0, 0.5, 0) }.play


// 12


(
    // a stereo version
    SynthDef.new(
        name: \tutorial_DecaySin2,
        ugenGraphFunc: {
            |outBus = 0, effectBus, direct = 0.5, freq = 440|
            var source;
            // 1.0.rand2 returns a random number from -1 to 1, used here for a random pan
            source = Pan2.ar(
                in: Decay2.ar(
                    in: Impulse.ar(
                        freq: Rand(0.3, 1),
                        phase: 0,
                        mul: 1.125
                    ),
                    attackTime: 0.3,
                    decayTime: 1,
                    mul: SinOsc.ar(
                        freq: SinOsc.kr(
                            freq: 0.2,
                            phase: 0,
                            mul: 110,
                            add: freq
                        )
                    )
                ),
                pos: Rand(-1.0, 1.0)
            );
            Out.ar(
                bus: outBus,
                channelsArray: source * direct
            );
            Out.ar(
                bus: effectBus,
                channelsArray: source * (1 - direct)
            );
        }
    ).add;

    SynthDef.new(
        name: \tutorial_Reverb2,
        ugenGraphFunc: {
            |outBus = 0, inBus|
            var input;
            input = In.ar(
                bus: inBus,
                numChannels: 2
            );
            16.do({ input = AllpassC.ar(
                in: input,
                maxdelaytime: 0.04,
                delaytime: Rand(0.001, 0.04),
                decaytime: 3
            )});
            Out.ar(
                bus: outBus,
                channelsArray: input
            );
        }
    ).add;
)

// now we create groups for effects and synths
(
    ~sources = Group.new;
    ~effects = Group.after(~sources); // make sure it's after
    ~bus = Bus.audio(
        server: s,
        numChannels: 2
    ); // this will be our stereo effects bus
)

// now synths in the groups. The default addAction is \addToHead
(
    x = Synth.new(
        defName: \tutorial_Reverb2,
        args: [
            \inBus, ~bus
        ],
        target: ~effects
    );
)
(
    y = Synth.new(
        defName: \tutorial_DecaySin2,
        args: [
            \effectBus, ~bus,
            \outBus, 0
        ],
        target: ~sources
    );
)
(
    z = Synth.new(
        defName: \tutorial_DecaySin2,
        args: [
            \effectBus, ~bus,
            \outBus, 0,
            \freq, 660
        ],
        target: ~sources
    );
)

// we could add other source and effects synths here

~sources.free; ~effects.free; // this frees their contents (x, y, z) as well
~bus.free;

// remove references to ~sources and ~effects environment variables:
currentEnvironment.clear;


