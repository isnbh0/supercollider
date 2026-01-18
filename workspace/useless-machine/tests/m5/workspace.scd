// ============================================================
// M5 WORKSPACE - Main control surface
// ============================================================

// === SETUP (run this first) ===
(
var dir = thisProcess.nowExecutingPath.dirname;
(dir +/+ "setup.scd").load;
(dir +/+ "wildcard.scd").load;
~wcPath = thisProcess.nowExecutingPath;
~wcDoc = ~getDocByPath.(~wcPath);
"[WORKSPACE] Ready. Target: %".format(~wcDoc.title).postln;
)

// === WILDCARD CONTROLS ===

~wcStart.();

~wcSetLevel.(2);

~wcStop.();

// ============================================================
// CONTROL KNOBS (wildcard mutates these)
// ============================================================

~jitter.(.....);

~speed.(....);

~reverb.(......);

// ============================================================
