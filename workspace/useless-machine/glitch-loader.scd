
(

if(~initialized.isNil) {
  var efxSetup;

  ~reverbBus = Bus.audio(s, 2);
  ~delayBus = Bus.audio(s, 2);
  ~delayTime = [0.25, 0.25];

  efxSetup = {

	Ndef(\lfo).play;

	~reverb = {
	  GVerb.ar(In.ar(~reverbBus, 2), 100, 6.0);
	}.play(0, addAction: \addToTail);

	~delay = {|deltime = #[0.25, 0.25]|
	  CombN.ar(In.ar(~delayBus, 2), 2.0, deltime, 2.0);
	}.play(0, addAction: \addToTail);

	{
	  ~delay.set(\deltime, ~delayTime);
	}.defer(0.5);
  };

  ServerTree.add(efxSetup);

  ~setDelayTime = {|delTime|
	~delayTime = delTime;
	~delay.set(\deltime, ~delayTime);
  };

  efxSetup.();

  ~samplePack = [
	"00.The_Amen_Break.wav",
	"01.DnB_Classic_Break.wav",
	"02.Wires_Crossed_Beat.wav",
	"03.triphop_beat.wav",
	"04.Warm_Fireside_Piano.wav",
	"05.The_Way_Piano_Progression.wav",
	"06.First_Class_Piano.wav",
	"07.Smooth_Jazz_Piano_01.wav",
	"08.Upright_Func_Bass_03.wav",
	"09.West_End_Bass_03.wav",
	"10.Wrong_Time_Sub_Bass_02.wav",
	"11.Saturday_Night_Guitar.wav",
	"12.Breaking_Waves_Guitar_01.wav",
	"13.Solace_All.wav",
	"14.Academy_Violin_02.wav",
	"15.Bpm80_Abm_NightRider_Strings.wav",
	"16.Rap-Acapella.wav",
	"17.AlvaNoto_C7_01.wav",
	"18.AlvaNoto_C7_02.wav",
	"19.AlvaNoto_ID_01.wav"
  ].collect({|path|
	Buffer.read(s, Document.current.dir ++ "/samplepack/" ++ path);
  });


  ~listen = {|buffer|
	{
	  PlayBuf.ar(1, buffer, doneAction: Done.freeSelf) ! 2;
	}.play;
  };

  ~lfo = 32.collect{ Bus.control() };

  ~initialized = true;
};



SynthDef(\wesa_sampler, {|sample = 0, start = 0, dur = 1, rate = 1, sr = 1.0, bits = 1, lpf = 20000, res = 1.0, hpf = 10, amp = 1.0, pan = 0.0, rev = 0.0, del = 0.0|
  var srate = BufSampleRate.kr(sample);
  var frames = BufFrames.kr(sample);
  var startPos = frames * start;
  var phaseFwd = Line.ar(startPos, startPos + (srate * dur), dur * rate.abs.reciprocal);
  var phaseRev = Line.ar(startPos + (srate * dur), startPos , dur * rate.abs.reciprocal);
  var phase = Select.ar(rate > 0, [phaseRev, phaseFwd]);
  var env = Env([1.0, 1.0, 0.0], dur*[0.9, 0.1]).ar(Done.freeSelf);
  var sig = BufRd.ar(1, sample, phase) * env * amp;
  sig = HPF.ar(sig, hpf);
  sig = RLPF.ar(sig, lpf, res);
	// sig = Decimator.ar(sig, 44100 * sr, 24 * bits );
  sig = Pan2.ar(sig, pan);
  Out.ar(0, sig);
  Out.ar(~reverbBus, sig * rev);
  Out.ar(~delayBus, sig * del);
}).add;



SynthDef(\wesa_granulator, {|sample = 0, dur = 1, start = 0, end = 0, size = 0.2, genHz = 1, rate = 1, pan = 0.0, amp = 1.0, lpf = 20000, hpf = 10, rev = 0.0, del = 0.0|
  var env = Env([1,1,0], dur*[0.9,0.1]).ar(Done.freeSelf);
  var pos = Line.ar(start, end, dur);
  var sig = GrainBuf.ar(1, Impulse.ar(genHz), size, sample, rate, pos);
  sig = HPF.ar(sig, hpf);
  sig = LPF.ar(sig, lpf);
  sig = Pan2.ar(sig * env * amp, pan);
  Out.ar(0, sig);
  Out.ar(~reverbBus, sig * rev);
  Out.ar(~delayBus, sig * del);
}).add;



SynthDef(\wesa_fm, {|out, freq = 440, dur = 1.0, attk = 0.0, rel= 0.1, pan = 0.0, amp= 0.5, rev = 0, del = 0|
  var env = EnvGen.ar(Env.new([0,0.5,0.5,0.0], dur*[attk, 1-(attk+rel), rel]), doneAction:2);
  var mod =  SinOsc.ar(freq * \ratio.kr(1), 0, \indx.kr(0));
  var sig = SinOsc.ar(freq, mod, env*amp);
  sig = Pan2.ar(sig, pan);
  Out.ar(out, sig);
  Out.ar(~reverbBus, sig*rev);
  Out.ar(~delayBus, sig*del);
}).add;


SynthDef(\wesa_analog, {|out, freq = 440, dur = 1.0, attk = 0.0, rel= 0.1, pan = 0.0, amp= 0.5, rev = 0, del = 0, wave = 0, pw = 0.5, cutoff = 8000, res = 1.0|
  var env = EnvGen.ar(Env.new([0,0.5,0.5,0.0], dur*[attk, 1-(attk+rel), rel]), doneAction:2);
  var sig = Select.ar(wave, [ Saw.ar(freq), Pulse.ar(freq, pw), LFTri.ar(freq), WhiteNoise.ar(0.6) ]);
  sig = RLPF.ar(sig, cutoff, res);
  sig = Pan2.ar(sig * env * amp, pan);
  Out.ar(out, sig);
  Out.ar(~reverbBus, sig*rev);
  Out.ar(~delayBus, sig*del);
}).add;

)
