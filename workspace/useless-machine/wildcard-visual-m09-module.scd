// ============================================================
// M0.9 MODULE: BYTE ↔ UTF-16 POSITION CONVERTER
// ============================================================
// Pure module file - no tests, just function definitions.
// Load from another file:
//   (PathName(thisProcess.nowExecutingPath).pathOnly +/+ "wildcard-visual-m09-module.scd").load;
// ============================================================

// Determine UTF-8 byte length from leading byte
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

// UTF-16 code unit count for a codepoint (4-byte UTF-8 = surrogate pair = 2 units)
~utf16UnitCount = {|utf8ByteLen|
    if(utf8ByteLen == 4, { 2 }, { 1 });
};

// Convert byte position to UTF-16 position (for use with Document.selectRange)
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

"[M0.9] Converter functions loaded: ~byteToUtf16, ~utf16ToByte".postln;
