// ============================================================
// M1.5 TEST UTILITIES - Third file for cross-file testing
// ============================================================
// This file exists solely to be modified by code loaded elsewhere.
// It contains a marker that test-changer-logic.scd will find and change.
// ============================================================

// MARKER_UTIL: <<<UNCHANGED>>>

// Some dummy content to make this a realistic file
~utilityFunction = {
    "This is a utility function".postln;
};

~anotherUtility = { |x, y|
    x + y
};

// End of file
