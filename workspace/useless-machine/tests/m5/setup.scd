// ============================================================
// M5 SETUP - Utility functions for workspace
// ============================================================
// Loaded by workspace.scd - do not run directly
// ============================================================

// === UTF-8/UTF-16 CONVERTERS ===

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

~utf16UnitCount = {|utf8ByteLen|
    if(utf8ByteLen == 4, { 2 }, { 1 });
};

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

// === DOCUMENT HELPERS ===

~getDocByFilename = {|filename|
    Document.allDocuments.detect { |d| d.title == filename };
};

~getOrOpenDoc = {|path|
    var filename = PathName(path).fileName;
    var doc = ~getDocByFilename.(filename);
    if (doc.isNil) {
        var currentDoc = Document.current;
        doc = Document.open(path);
        currentDoc.front;
    };
    doc;
};

// Get doc by path - no focus steal, returns nil if not open
~getDocByPath = {|path|
    Document.allDocuments.detect { |d| d.path == path };
};

~replaceContent = {|doc, controllerName, newValue|
    var text, pattern, patternPos, contentStart, contentEnd, depth;
    var utf16Start, utf16Len;

    text = doc.string;
    pattern = "~" ++ controllerName ++ ".(";
    patternPos = text.find(pattern);

    if (patternPos.isNil) {
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

        utf16Start = ~byteToUtf16.(text, contentStart);
        utf16Len = ~byteToUtf16.(text, contentEnd) - utf16Start;

        doc.selectRange(utf16Start, utf16Len);
        doc.selectedString_(newValue);
        true;
    };
};

"[SETUP] Loaded".postln;
