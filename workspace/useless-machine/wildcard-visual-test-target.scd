// ============================================================
// WILDCARD VISUAL TEST TARGET
// ============================================================
// Minimal fixture for M1 testing. DO NOT MODIFY during tests.
// Mirrors soundtest.scd control panel structure.
// ============================================================

// Some preamble text to create realistic byte offsets
// This comment contains unicode: → 한글 🎹
// The above adds drift for byte↔UTF-16 testing

// ==================== CONTROLS ====================

( ~rev.(
    "........."
))

( ~speed.(
    "....."
))

( ~jitter.(
    "...."
))

( ~silence.(
    "......."
))

( ~fade.(
    ".."
))

( ~stut.(
    "......"
))

( ~grain.(
    "..."
))

// ==================== ADJUSTMENTS ====================

// End of control panel. More content below to test position accuracy.

~somethingElse = { "not a controller" };
