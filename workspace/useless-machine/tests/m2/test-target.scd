// ============================================================
// M2/M3 TEST TARGET - Controllers to be modified
// ============================================================
// Edge cases for thorough testing.
// ============================================================

// === BASIC CASES ===
~basic.(.......);
~tiny.(..);
~huge.(....................);

// === NON-DOT PLACEHOLDERS ===
~letters.(xxxxxxxx);
~mixed.(a1b2c3d4);
~underscores.(________);

// === WHITESPACE ===
~empty.();
~spaced.(        );
~multiline.(....
....
....);

// === UNICODE (BMP - 3 byte UTF-8, 1 UTF-16) ===
~arrows.(→→→→);
~korean.(한글한글);

// === UNICODE (NON-BMP - 4 byte UTF-8, 2 UTF-16 surrogate pairs) ===
~emoji.(0.3
~musical.(𝄞𝄞𝄞);

// === AFTER UNICODE (drift test) ===
~afterunicode.(.....);

// === NESTED PARENS ===
~nested.(((.....)));

// === ADVERSARIAL: Semicolon in content ===
~semis.(a;b;c);

// === ADVERSARIAL: Tilde pattern in content ===
~meta.(~fake.(xxx));

// === ADVERSARIAL: Zero-width spaces (U+200B between letters) ===
~zerowidth.(a​b​c);
// === ADVERSARIAL: Mixed BMP and non-BMP ===
~mixedplanes.(한🎵글🎵);

// === ADVERSARIAL: Special chars (no escaping issues) ===
~special.(<>[]{}!@#$%);

// END_MARKER: OK
