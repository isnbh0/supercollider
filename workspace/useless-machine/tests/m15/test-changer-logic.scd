// ============================================================
// M1.5 CHANGER LOGIC - Loaded module for cross-file mutation
// ============================================================
// This file is LOADED (not executed directly).
// It returns a function that modifies text in any target document.
// ============================================================

// MARKER_CHANGER: <<<UNCHANGED>>>

// Return a function that performs the modification
{ |targetPath, markerPrefix, oldValue, newValue|
    var doc;

    "[CHANGER] Target: %".format(PathName(targetPath).fileName).postln;
    "[CHANGER] Looking for: % %".format(markerPrefix, oldValue).postln;

    // Open target document (may already be open)
    doc = Document.open(targetPath);

    if (doc.isNil) {
        "[CHANGER] ERROR: Could not open document".postln;
    } {
        // Defer to ensure document is ready
        {
            var text, searchPattern, bytePos, replacePattern, utf16Pos, utf16Len;
            var altSearch, altPos, snippet;

            text = doc.string;

            if (text.isNil) {
                "[CHANGER] ERROR: doc.string is nil".postln;
            } {
                searchPattern = markerPrefix ++ ": " ++ oldValue;
                bytePos = text.find(searchPattern);

                "[CHANGER] doc.string.size: %".format(text.size).postln;
                "[CHANGER] searchPattern: '%'".format(searchPattern).postln;
                "[CHANGER] bytePos: %".format(bytePos).postln;

                if (bytePos.notNil) {
                    replacePattern = markerPrefix ++ ": " ++ newValue;
                    utf16Pos = ~byteToUtf16.(text, bytePos);
                    utf16Len = ~byteToUtf16.(text, bytePos + searchPattern.size) - utf16Pos;

                    "[CHANGER] UTF-16 pos: %, len: %".format(utf16Pos, utf16Len).postln;

                    // Perform the replacement
                    doc.selectRange(utf16Pos, utf16Len);
                    doc.selectedString_(replacePattern);

                    "[CHANGER] SUCCESS: Replaced in %".format(PathName(targetPath).fileName).postln;
                } {
                    "[CHANGER] Pattern not found. Already changed?".postln;

                    // Debug: show what's around the marker
                    altSearch = markerPrefix ++ ":";
                    altPos = text.find(altSearch);
                    if (altPos.notNil) {
                        snippet = text[altPos..(altPos + 40).min(text.size - 1)];
                        "[CHANGER] Found marker at: '%'".format(snippet).postln;
                    };
                };
            };
        }.defer(0.3);
    };
}
