// ============================================================
// M5 UTILS MODULE - Consolidated from M0.9-M4
// ============================================================
// Load with: (thisProcess.nowExecutingPath.dirname +/+ "utils.scd").load
// ============================================================

// === UTF-8/UTF-16 CONVERTERS (from M0.9) ===

// Determine UTF-8 byte length from leading byte (handles signed bytes)
~utf8ByteLength = {|leadingByte|
    var code = leadingByte.ascii;
    case
        { code < 0 } {
            var unsigned = code + 256;
            case
                { unsigned < 194 } { 1 }
                { unsigned < 224 } { 2 }
                { unsigned < 240 } { 3 }
                { unsigned < 248 } { 4 }
                { 1 };
        }
        { code < 128 } { 1 }
        { 1 };
};

// UTF-16 code unit count (4-byte UTF-8 = surrogate pair = 2 units)
~utf16UnitCount = {|utf8ByteLen|
    if(utf8ByteLen == 4, { 2 }, { 1 });
};

// Convert byte position to UTF-16 position (for Document.selectRange)
~byteToUtf16 = {|text, bytePos|
    var byteIdx = 0, utf16Idx = 0, textSize = text.size;
    while { byteIdx < bytePos and: { byteIdx < textSize } } {
        var byteLen = ~utf8ByteLength.(text[byteIdx]);
        var utf16Len = ~utf16UnitCount.(byteLen);
        byteIdx = byteIdx + byteLen;
        utf16Idx = utf16Idx + utf16Len;
    };
    utf16Idx;
};

// Convert UTF-16 position to byte position (for String indexing)
~utf16ToByte = {|text, utf16Pos|
    var byteIdx = 0, utf16Idx = 0, textSize = text.size;
    while { utf16Idx < utf16Pos and: { byteIdx < textSize } } {
        var byteLen = ~utf8ByteLength.(text[byteIdx]);
        var utf16Len = ~utf16UnitCount.(byteLen);
        byteIdx = byteIdx + byteLen;
        utf16Idx = utf16Idx + utf16Len;
    };
    byteIdx;
};

// === DOCUMENT HELPERS (from M1.5/M4) ===

// Get document handle by filename without stealing focus
~getDocByFilename = {|filename|
    var doc = Document.allDocuments.detect { |d| d.title == filename };
    if (doc.isNil) {
        "[UTILS] Document '%' not found in open documents".format(filename).postln;
    };
    doc;
};

// Get document handle, opening if needed (returns focus to caller)
~getOrOpenDoc = {|path|
    var filename = PathName(path).fileName;
    var doc = Document.allDocuments.detect { |d| d.title == filename };
    if (doc.isNil) {
        var currentDoc = Document.current;
        doc = Document.open(path);
        currentDoc.front;  // Return focus
        "[UTILS] Opened '%' (returned focus)".format(filename).postln;
    };
    doc;
};

// Replace content between ~name.( and )
~replaceContent = {|doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth;
    var utf16Start, utf16Len;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[UTILS] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        contentStart = patternPos + pattern.size;

        // Find matching close paren (handle nested parens)
        contentEnd = contentStart;
        depth = 1;
        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };

        // Convert to UTF-16
        utf16Start = ~byteToUtf16.(text, contentStart);
        utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

        // Replace
        doc.selectRange(utf16Start, utf16Len);
        doc.selectedString_(newValue);

        true;
    };
};

// Insert text before a controller (at line start)
~insertBefore = {|doc, controllerName, insertText|
    var text, pattern, patternPos, lineStart, utf16Start;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[UTILS] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        // Find line start (search backwards for newline)
        lineStart = text[0..patternPos].findBackwards("\n");
        lineStart = if(lineStart.isNil, { 0 }, { lineStart + 1 });

        // Insert at line start
        utf16Start = ~byteToUtf16.(text, lineStart);
        doc.selectRange(utf16Start, 0);
        doc.selectedString_(insertText);

        true;
    };
};

// Verify controller has expected content
~verifyContent = {|doc, controllerName, expectedValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth, actual;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
        "[UTILS] Controller '%' not found".format(controllerName).postln;
        false;
    } {
        contentStart = patternPos + pattern.size;
        contentEnd = contentStart;
        depth = 1;
        while { (depth > 0) && (contentEnd < text.size) } {
            case
                { text[contentEnd] == $( } { depth = depth + 1 }
                { text[contentEnd] == $) } { depth = depth - 1 };
            if (depth > 0) { contentEnd = contentEnd + 1 };
        };

        actual = text[contentStart..(contentEnd - 1)];
        actual == expectedValue;
    };
};

"[M5-UTILS] Loaded: ~byteToUtf16, ~utf16ToByte, ~getDocByFilename, ~getOrOpenDoc, ~replaceContent, ~insertBefore, ~verifyContent".postln;
