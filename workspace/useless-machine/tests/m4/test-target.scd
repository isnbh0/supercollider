~firstLine.(...);
// ============================================================
// M4 TEST TARGET - Repeated Operations with Breadcrumbs
// ============================================================
// Standalone fixture for M4 tests.
// ============================================================

// === CONTROLLERS ===
~alpha.(.......);
~beta.(....);
~gamma.(..........);

// === ADJACENT CONTROLLERS (no blank line between) ===
~adj1.(AAA);
~adj2.(BBB);

// === STRESS TEST CONTROLLERS ===
~s01.(.); ~s02.(.); ~s03.(.); ~s04.(.); ~s05.(.);
~s06.(.); ~s07.(.); ~s08.(.); ~s09.(.); ~s10.(.);

// === AFTER CONTROLLERS ===
~final.(.....);

// END_MARKER: OK