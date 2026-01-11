// ================================================================================
// WILDCARD: Autonomous Chaos Engine / 자율 카오스 엔진
//
// An "evil bug" that randomly mutates soundtest.scd parameters.
// soundtest.scd 파라미터를 무작위로 변이시키는 "악성 버그"
//
// Usage:
//   (Document.current.dir ++ "/wildcard.scd").load;  // Load definitions
//   ~wildcardStart.();     // Begin chaos (auto-snapshots state first)
//   ~wildcardStop.();      // Stop chaos
//   ~wildcardSetLevel.(3); // Set chaos level 1-5
//   ~wildcardCoda.();      // Final 30-sec collapse
//   ~wildcardRecover.();   // Emergency stop + restore state
//
// MUTATIONS (5 types):
//   1. STUTTER  - 스터터: 높은 확률 + 짧은 지속시간
//   2. JITTER   - 지터: 시작점 랜덤화
//   3. SAMPLE   - 샘플: 다른 샘플로 전환
//   4. IMPACT   - 임팩트: 버스트/침묵
//   5. GLITCH   - 글리치: 글리치 모드 강제 활성화
// ================================================================================

(
// === VERIFICATION ===
~wildcardVerify = {
    if(~soundtestReady != true, {
        "오류: soundtest 준비 안됨 - ~prep.() 먼저 실행하세요".postln;
        ^false;
    });
    if(~samplePack.isNil or: { ~samplePack.size == 0 }, {
        "오류: 샘플 없음 - ~boot.() 먼저 실행하세요".postln;
        ^false;
    });
    if(~sampleRegistry.isNil or: { ~sampleRegistry.size == 0 }, {
        "오류: 샘플 레지스트리 없음 - ~boot.() 먼저 실행하세요".postln;
        ^false;
    });
    true;
};

// === CHAOTIC TEXT ELEMENTS ===
// Zalgo-like, broken ASCII, random CJK, glitch text
~chaosGlyphs = [
    "̈́", "̈", "̀", "́", "̂", "̃", "̄", "̅", "̆", "̇", "̊", "̋", "̌", "̍", "̎", "̏",
    "░", "▒", "▓", "█", "▄", "▀", "■", "□", "▪", "▫", "◊", "○", "●", "◐", "◑",
    "╳", "╬", "╫", "╪", "┼", "┿", "╂", "╃", "╄", "╅", "╆", "╇", "╈", "╉", "╊",
    "▲", "△", "▼", "▽", "◄", "►", "◁", "▷", "⬡", "⬢", "⬣",
];

~chaosCJK = [
    // Random hangul syllables (from full 11172 range)
    "겋", "꿭", "뗐", "륩", "믾", "볿", "쑠", "읾", "쭶", "킇",
    "햏", "긿", "낾", "댧", "렟", "몋", "봶", "숖", "욽", "줻",
    "춯", "큲", "튡", "퓻", "휳", "긕", "놂", "됀", "룀", "뫼",
    "뵀", "쇳", "욈", "쥐", "츼", "큄", "틔", "픠", "흴", "깋",
    "넹", "뎧", "렝", "몡", "봿", "숳", "욿", "줾", "춻", "큽",
    // Random kanji
    "龘", "齉", "靐", "鑫", "麤", "驫", "鱻", "爨", "灪", "籱",
    // Random katakana/hiragana
    "ヰ", "ヱ", "ヴ", "ヵ", "ヶ", "ゐ", "ゑ", "ゔ", "ゕ", "ゖ",
];

~chaosZalgo = [
    "T̷̨̛͇̈́̅͛", "H̶̡̧͂̌͗̕", "Ȅ̵̳͆̕", "V̷̡̓̂̔", "Ǫ̴̽̓̿̑",
    "I̶̢̛̾̿̔͝", "Ḑ̴̛̓̽͝", "C̵̨̛̾̿̔͝", "A̵̧̽̓̿",
    "에̷͇̈́̅͛러̶͂̌͗", "오̵̏͆̕류̷̓̂̔", "버̴̽̓̿̑그̶̾̿̔͝",
];

~chaosBroken = [
    // Absurdist fever dream
    "FLESHCLOCK", "GRANDMOTHER.EXE", "TUNGSTEN MILK", "CARPET THEOREM",
    "OSSUARY WIFI", "VELVET STATIC", "MOLAR CATHEDRAL", "SOUP DIMENSION",
    "FIBULA BROADCAST", "UNCLE FREQUENCY", "ANTIMATTER PICNIC", "DOOR.NULL",
    "SCALP GEOMETRY", "THERMAL CUSTARD", "VERB FUNGUS", "SPLEEN CAROUSEL",
    "INFINITE NAPKIN", "MEAT WEDNESDAY", "PARALLAX UNCLE", "TOOTH ECONOMY",
    // Multilingual glitch
    "QUARK::REFRIGERATOR", "PLASMA.SANDWICH", "MITOCHONDRIA_LAMP",
    "FERMION//TOASTER", "SPLEEN.NEBULA.EXE", "TUNGSTEN::YOGURT",
    "AXON>>CROUTON", "ANTIMATTER.SPOON.NULL", "SYNAPSE::BUCKET::VOID",
    "HADRON.COLLIDER.PANTS", "NEUTRINO//STAPLER.exe",
    // Corrupted memory
    "MEAT://VOID.404", "TEETH///TEETH///TEETH", "HORSE;;;;HORSE;;;;H0R53",
    "SKIN.TXT NOT FOUND", "EYE.EYE.EYE.EYE.I.I.I.I", "TABLE::TABLE::NULL",
    "GRANDMOTHER.DLL HAS OPINIONS", "MIRROR?MIRROR?MIRROR",
    // CJK glitch
    "무한양말", "量子キッチン", "엔트로피김치", "冷蔵庫の夢", "플라즈마비닐봉지",
    "無限廊下", "양자얽힘칫솔", "肘工場", "손?손?HAND.NULL", "椅子CHAIR椅子",
    "なに?WHAT?なに?", "空EMPTY空", "足FOOT足", "거울?MIRROR",
];

// Zalgo combining characters
~zalgoUp = [
    "̍", "̎", "̄", "̅", "̿", "̑", "̆", "̐", "͒", "͗", "͑", "̇", "̈", "̊", "͂", "̓",
    "̈́", "͊", "͋", "͌", "̃", "̂", "̌", "͐", "̀", "́", "̋", "̏", "̒", "̓", "̔", "̽",
];

~zalgoMid = ["̕", "̛", "̀", "́", "͘", "̡", "̢", "̧", "̨", "̴", "̵", "̶", "͜", "͝", "͞"];

~zalgoDown = [
    "̖", "̗", "̘", "̙", "̜", "̝", "̞", "̟", "̠", "̤", "̥", "̦", "̩", "̪", "̫", "̬",
    "̭", "̮", "̯", "̰", "̱", "̲", "̳", "̹", "̺", "̻", "̼", "ͅ", "͇", "͈", "͉", "͍",
];

// Apply zalgo to a string
~zalgoify = {|str, intensity = 3|
    var result, i, char;
    result = "";
    str.do {|c|
        result = result ++ c.asString;
        intensity.rand.do { result = result ++ ~zalgoUp.choose };
        (intensity div: 2).rand.do { result = result ++ ~zalgoMid.choose };
        intensity.rand.do { result = result ++ ~zalgoDown.choose };
    };
    result;
};

// Randomly space out a word: "SEAHORSE" -> "S EA HRoo  oORSE"
~glitchSpace = {|str|
    var result, char, flipped;
    result = "";
    str.do {|c, idx|
        // Random case flip using proper Char methods
        flipped = if(0.3.coin, {
            if(c.isUpper, { c.toLower }, {
                if(c.isLower, { c.toUpper }, { c })
            })
        }, { c });
        result = result ++ flipped.asString;
        // Random extra spaces
        if(0.25.coin, {
            (1 + 3.rand).do { result = result ++ " " };
        });
        // Random character repeat
        if(0.15.coin, {
            (1 + 2.rand).do { result = result ++ flipped.asString };
        });
    };
    result;
};

// Get a chaos word with random effects applied
~chaosWord = {
    var word, doZalgo, doSpace;
    word = ~chaosBroken.choose;
    doZalgo = 0.4.coin;
    doSpace = 0.5.coin;
    if(doSpace, { word = ~glitchSpace.(word) });
    if(doZalgo, { word = ~zalgoify.(word, 2 + (~wildcardLevel ? 1)) });
    word;
};

// Generate random chaos string
~chaosString = {|length = 10|
    var result, choice;
    result = "";
    length.do {
        choice = 5.rand;
        result = result ++ switch(choice,
            0, { ~chaosGlyphs.choose },
            1, { ~chaosCJK.choose },
            2, { ~chaosZalgo.choose },
            3, { ~chaosWord.() },  // Use the fancy version with zalgo/spacing
            4, { " " }  // Random spaces for chaos
        );
    };
    result;
};

// === THEATRICAL OUTPUT ===
// Repeat messages for dramatic effect (10x minimum)
~wildcardSpam = {|msg, times = 12|
    times.do {|i|
        // Add chaos at higher levels
        if(~wildcardLevel >= 4, {
            (~chaosString.(5) ++ " " ++ msg ++ " " ++ ~chaosString.(5)).postln;
        }, {
            msg.postln;
        });
    };
};

~wildcardBanner = {|lines|
    "".postln;
    12.do {|rep|
        // Add chaos decoration at higher levels
        if(~wildcardLevel >= 3, {
            ~chaosString.(20).postln;
        });
        lines.do {|line|
            if(~wildcardLevel >= 4, {
                (~chaosGlyphs.choose ++ ~chaosGlyphs.choose ++ " " ++ line ++ " " ++ ~chaosGlyphs.choose ++ ~chaosGlyphs.choose).postln;
            }, {
                line.postln;
            });
        };
        if(~wildcardLevel >= 3, {
            ~chaosString.(20).postln;
        });
        "".postln;
    };
};

// === MUTATION ACTIONS ===

// WILDCARD MUTATION 1: STUTTER / 스터터
// Pushes generators toward high-probability micro-duration bursts
~wildcardStutter = {
    var gen = 4.rand;
    var oldProb = ~genSpecs[gen][0];
    var oldDur = ~genSpecs[gen][1];
    var newProb = rrand(0.5, 1.0);
    var newDur = rrand(0.005, 0.05);

    // WILDCARD: STUTTER MUTATION
    ~genSpecs[gen][0] = newProb;
    ~genSpecs[gen][1] = newDur;

    ~wildcardSpam.(
        ">>> WILDCARD 스터터: gen" ++ gen ++
        " 확률=" ++ oldProb.round(0.01) ++ "->" ++ newProb.round(0.01) ++
        " 길이=" ++ (oldDur*1000).round(0.1) ++ "ms->" ++ (newDur*1000).round(0.1) ++ "ms <<<"
    );
};

// WILDCARD MUTATION 2: JITTER / 지터
// Increases start point randomization
~wildcardJitter = {
    var oldJitter = ~playheadJitter;
    var newJitter = rrand(0.1, 0.5);

    // WILDCARD: JITTER MUTATION
    ~playheadJitter = newJitter;

    ~wildcardSpam.(
        ">>> WILDCARD 지터: " ++ oldJitter.round(0.01) ++ " -> " ++ newJitter.round(0.01) ++ " 시작점 흔들림 <<<"
    );
};

// WILDCARD MUTATION 3: SAMPLE / 샘플
// Switches to a different sample from the pack
~wildcardSample = {
    var oldInfo = ~sampleRegistry.detect {|s| s.buffer == ~genSample };
    var newInfo = ~sampleRegistry.choose;
    var oldName;

    // Guard: need at least 2 samples to switch
    if(~sampleRegistry.size < 2, {
        ~wildcardSpam.(">>> WILDCARD 샘플: 전환할 샘플 부족 / not enough samples <<<");
        ^nil;
    });

    // Handle case where current sample isn't in registry
    oldName = if(oldInfo.notNil, { oldInfo.name }, { "???" });

    // Avoid same sample (safe now that we know size >= 2)
    while { newInfo.buffer == ~genSample } { newInfo = ~sampleRegistry.choose };

    // WILDCARD: SAMPLE MUTATION
    ~genSample = newInfo.buffer;

    ~wildcardBanner.([
        "========================================",
        "   WILDCARD 샘플 전환",
        "   " ++ oldName ++ " --> " ++ newInfo.name,
        "   다른 소리가 들린다...",
        "========================================"
    ]);
};

// WILDCARD MUTATION 4: IMPACT / 임팩트
// Sudden burst or silence
~wildcardImpact = {
    var action = [\burst, \silence].choose;

    switch(action,
        \burst, {
            // WILDCARD: IMPACT - BURST
            ~burstAll.(0.6);
            ~wildcardBanner.([
                "########################################",
                "###   WILDCARD 폭발   ##################",
                "###   BURST   ##########################",
                "########################################"
            ]);
        },
        \silence, {
            // WILDCARD: IMPACT - SILENCE
            ~silenceAll.();
            ~wildcardBanner.([
                "                                        ",
                "   . . . WILDCARD 침묵 . . .            ",
                "   . . . SILENCE . . .                  ",
                "                                        "
            ]);
        }
    );
};

// WILDCARD MUTATION 5: GLITCH MODE / 글리치 모드
// Forcibly enables glitch mode
~wildcardGlitch = {
    // WILDCARD: GLITCH MODE MUTATION
    ~glitchMode.();

    ~wildcardSpam.(
        ">>> WILDCARD 글리치 모드 강제 활성화 <<<"
    );
};

// === CHAOS LEVELS / 카오스 레벨 ===
// Each level defines available actions and timing
~chaosLevels = [
    // Level 1: 미묘함 - jitter only, slow
    (
        name: "미묘함 SUBTLE",
        interval: [8, 15],
        actions: [\jitter],
    ),
    // Level 2: 눈에 띔 - add stutter
    (
        name: "눈에 띔 NOTICEABLE",
        interval: [5, 10],
        actions: [\jitter, \stutter],
    ),
    // Level 3: 방해 - add sample switching
    (
        name: "방해 DISRUPTIVE",
        interval: [3, 6],
        actions: [\jitter, \stutter, \sample],
    ),
    // Level 4: 혼돈 - add impacts
    (
        name: "혼돈 CHAOTIC",
        interval: [2, 4],
        actions: [\jitter, \stutter, \sample, \impact],
    ),
    // Level 5: 완전한 카오스 - everything including glitch mode
    (
        name: "완전한 카오스 TOTAL CHAOS",
        interval: [1, 2],
        actions: [\jitter, \stutter, \sample, \impact, \glitch],
    ),
];

~wildcardLevel = 1;
~wildcardRunning = false;
~wildcardRoutine = nil;
~wildcardMutationCount = 0;

// === SET LEVEL ===
~wildcardSetLevel = {|level|
    var config;
    ~wildcardLevel = level.clip(1, 5);
    config = ~chaosLevels[~wildcardLevel - 1];

    ~wildcardBanner.([
        "================================================",
        "   WILDCARD 카오스 레벨: " ++ ~wildcardLevel,
        "   " ++ config.name,
        "   가능한 변이: " ++ config.actions,
        "================================================"
    ]);
};

// === EXECUTE MUTATION ===
~wildcardMutate = {
    var config = ~chaosLevels[~wildcardLevel - 1];
    var action = config.actions.choose;

    ~wildcardMutationCount = ~wildcardMutationCount + 1;

    switch(action,
        \stutter, { ~wildcardStutter.() },
        \jitter, { ~wildcardJitter.() },
        \sample, { ~wildcardSample.() },
        \impact, { ~wildcardImpact.() },
        \glitch, { ~wildcardGlitch.() }
    );
};

// === MAIN LOOP ===
~wildcardStart = {
    if(~wildcardVerify.() == false, { ^nil });

    if(~wildcardRunning, {
        "Wildcard 이미 실행 중".postln;
        ^nil;
    });

    // Auto-snapshot state before chaos begins
    ~stateSnapshot.();

    ~wildcardRunning = true;
    ~wildcardMutationCount = 0;

    ~wildcardBanner.([
        "================================================",
        "                                                ",
        "   W I L D C A R D   깨어난다                   ",
        "   W I L D C A R D   A W A K E N S              ",
        "                                                ",
        "   기계 속에서 무언가가 움직인다...             ",
        "   something stirs in the machine...            ",
        "                                                ",
        "================================================"
    ]);

    ~wildcardRoutine = {
        inf.do {|i|
            var config = ~chaosLevels[~wildcardLevel - 1];
            var interval = rrand(config.interval[0], config.interval[1]);

            // Wait before mutation (pacing - don't overwhelm)
            interval.wait;

            // Execute mutation
            ~wildcardMutate.();

            // Extra cooldown after mutation (1-2 beats breathing room)
            rrand(1.0, 2.0).wait;
        };
    }.fork;

    "Wildcard 시작 레벨 " ++ ~wildcardLevel;
};

// === STOP ===
~wildcardStop = {
    if(~wildcardRoutine.notNil, {
        ~wildcardRoutine.stop;
        ~wildcardRoutine = nil;
    });
    ~wildcardRunning = false;

    ~wildcardBanner.([
        "================================================",
        "   WILDCARD 정지                                ",
        "   WILDCARD HALTED                              ",
        "   총 변이 횟수: " ++ ~wildcardMutationCount,
        "================================================"
    ]);
};

// === PAUSE / RESUME ===
~wildcardPause = {
    if(~wildcardRoutine.notNil, {
        ~wildcardRoutine.pause;
        ~wildcardSpam.(">>> WILDCARD 일시정지 / PAUSED <<<");
    });
};

~wildcardResume = {
    if(~wildcardRoutine.notNil, {
        ~wildcardRoutine.resume;
        ~wildcardSpam.(">>> WILDCARD 재개 / RESUMED <<<");
    });
};

// === RECOVERY ===
~wildcardRecover = {
    ~wildcardStop.();
    ~stateRestore.();

    ~wildcardBanner.([
        "================================================",
        "                                                ",
        "   시 스 템   복 구 됨                          ",
        "   S Y S T E M   R E C O V E R E D              ",
        "                                                ",
        "   카오스가 봉인되었다... 일단은               ",
        "   chaos contained... for now                   ",
        "                                                ",
        "================================================"
    ]);
};

// === STATUS ===
~wildcardStatus = {
    var config = ~chaosLevels[~wildcardLevel - 1];
    "".postln;
    "=== WILDCARD 상태 ===".postln;
    ("실행 중: " ++ ~wildcardRunning).postln;
    ("레벨: " ++ ~wildcardLevel ++ " - " ++ config.name).postln;
    ("변이 횟수: " ++ ~wildcardMutationCount).postln;
    ("가능한 변이: " ++ config.actions).postln;
    "".postln;
};

// === CODA: FINAL COLLAPSE / 코다: 최후의 붕괴 ===
// 30 seconds of escalating chaos, then crash
~wildcardCoda = {
    var codaDuration = 30;
    var startTime = Main.elapsedTime;

    ~wildcardStop.();  // Stop normal routine

    ~wildcardBanner.([
        "################################################",
        "#                                              #",
        "#   치 명 적   불 안 정                        #",
        "#   C R I T I C A L   I N S T A B I L I T Y    #",
        "#                                              #",
        "#   코다 시작 - 붕괴까지 30초                  #",
        "#   CODA INITIATED - 30 SECONDS TO COLLAPSE    #",
        "#                                              #",
        "################################################"
    ]);

    ~wildcardRunning = true;

    ~wildcardRoutine = {
        var elapsed, progress, interval, mutations, bar, filled;

        inf.do {|i|
            elapsed = Main.elapsedTime - startTime;
            progress = (elapsed / codaDuration).clip(0, 1);

            // Interval shrinks: 2s -> 0.05s (NO COOLDOWN in coda!)
            interval = 2 * ((0.025) ** progress);

            // Mutations per tick: 1 -> 5
            mutations = (1 + (4 * progress)).asInteger;

            // Force level 5 (all actions available)
            ~wildcardLevel = 5;

            // Multiple mutations per tick (coda = no cooldown, all bets off)
            mutations.do {
                ~wildcardMutate.();
            };

            // Progress indicator
            if(i % 5 == 0, {
                bar = "";
                filled = (progress * 30).asInteger;
                filled.do { bar = bar ++ "#" };
                (30 - filled).do { bar = bar ++ "." };
                ~wildcardSpam.(
                    "붕괴: [" ++ bar ++ "] " ++ (progress * 100).asInteger ++ "%",
                    3
                );
            });

            // Final moments - spawn synth flood
            if(progress > 0.9, {
                ~wildcardBanner.([
                    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!",
                    "!!! 완전한 붕괴 임박 !!!",
                    "!!! TOTAL COLLAPSE IMMINENT !!!",
                    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                ]);

                // Synth flood
                20.do {
                    Synth(\gen_sampler, [
                        \sample, ~samplePack.choose,
                        \start, 1.0.rand,
                        \dur, rrand(0.01, 0.5),
                        \amp, rrand(0.3, 0.8),
                        \pan, 1.0.rand2,
                        \fade, 0.001,
                        \rev, 1.0.rand,
                    ]);
                };
            });

            // Crash point
            if(progress >= 1.0, {
                ~wildcardBanner.([
                    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                    "X                                      X",
                    "X   완 전 한   붕 괴                   X",
                    "X   T O T A L   C O L L A P S E        X",
                    "X                                      X",
                    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                ]);

                // Final synth flood to overload
                100.do {|j|
                    Synth(\gen_sampler, [
                        \sample, ~samplePack.choose,
                        \start, 1.0.rand,
                        \dur, rrand(0.5, 5),
                        \amp, 0.5,
                        \pan, 1.0.rand2,
                        \fade, 0.001,
                        \rev, 1.0,
                    ]);
                    ("신스 " ++ j ++ " 생성됨 / SYNTH SPAWNED").postln;
                };

                ~wildcardRunning = false;
                ^nil;  // Exit routine
            });

            interval.wait;
        };
    }.fork;

    "코다 시작 - 돌아올 수 없는 지점 / CODA initiated - point of no return";
};

"=== WILDCARD 로드됨 ===".postln;
"컨트롤: ~wildcardStart.(), ~wildcardStop.(), ~wildcardSetLevel.(1-5), ~wildcardCoda.(), ~wildcardRecover.()".postln;
)

// ==================== CONTROLS ====================

// Load wildcard
( (Document.current.dir ++ "/wildcard.scd").load; )

// Start/stop
( ~wildcardStart.(); )
( ~wildcardStop.(); )

// Set chaos level (1-5)
( ~wildcardSetLevel.(1); )  // 미묘함 SUBTLE
( ~wildcardSetLevel.(2); )  // 눈에 띔 NOTICEABLE
( ~wildcardSetLevel.(3); )  // 방해 DISRUPTIVE
( ~wildcardSetLevel.(4); )  // 혼돈 CHAOTIC
( ~wildcardSetLevel.(5); )  // 완전한 카오스 TOTAL CHAOS

// Pause/resume
( ~wildcardPause.(); )
( ~wildcardResume.(); )

// Status
( ~wildcardStatus.(); )

// Recovery (emergency stop + restore state)
( ~wildcardRecover.(); )

// Manual triggers (for testing)
( ~wildcardStutter.(); )
( ~wildcardJitter.(); )
( ~wildcardSample.(); )
( ~wildcardImpact.(); )
( ~wildcardGlitch.(); )

// CODA: Final 30-second collapse (point of no return!)
// 코다: 최후의 30초 붕괴 (돌아올 수 없음!)
( ~wildcardCoda.(); )
