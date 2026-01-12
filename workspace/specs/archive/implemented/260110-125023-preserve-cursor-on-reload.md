# SCIDE - Preserve Cursor Position on Auto-Reload

**Date:** 2026-01-10 12:50:23
**Issue:** Auto-reload of externally modified files resets cursor position to document start
**Priority:** Medium
**Status:** Completed
**Implementation:**
- Commit: 1a455efd4 - feat(scide): preserve cursor position on auto-reload
**Completed:** 2026-01-10

## Problem Statement

- **Current behavior:** When a file is auto-reloaded due to external modification (with `autoReloadExternalChanges` enabled), the cursor position is reset to the beginning of the document (position 0), and scroll position is lost.
- **Expected behavior:** The cursor should remain at its logical position in the document, even when content before or around the cursor has changed.
- **Impact:** Users lose their place in the document when external tools (formatters, git operations, etc.) modify files, requiring manual navigation back to their working location.

## Root Cause Analysis

The `DocumentManager::reload()` method in `editors/sc-ide/core/doc_manager.cpp:362-387` replaces the entire document content via `setPlainText()` without preserving cursor state:

```cpp
// editors/sc-ide/core/doc_manager.cpp:377
doc->mDoc->setPlainText(decodeDocument(bytes));  // Cursor is reset here
```

The `setPlainText()` call on `QTextDocument` clears all cursor positions because it replaces the entire document content. No code exists to save cursor state before this operation or restore it afterward.

### Key Edge Case: Content Changes Around Cursor

Simple position clamping fails when content changes before or around the cursor:

| Scenario | Simple Clamp Result | Expected Result |
|----------|---------------------|-----------------|
| 10 lines inserted before cursor | Cursor stays at old position (wrong line) | Cursor moves down 10 lines |
| Line containing cursor deleted | Cursor at arbitrary position | Cursor at nearest surviving line |
| Cursor line reformatted | Cursor mid-word on wrong content | Cursor at same logical column |

A diff-based approach maps the old cursor position through the changes to find the equivalent new position.

## Technical Approach

### Modular Architecture

Extract cursor position mapping into a separate function to allow easy strategy substitution:

```cpp
// Pure function: maps old position to new position based on content diff
int mapCursorPosition(const QString& oldContent, const QString& newContent, int oldPosition);
```

This separation enables:
1. Unit testing the mapping logic independently
2. Swapping strategies without touching reload() logic
3. Future enhancements (selection preservation, multiple cursors)

### Diff-Based Position Mapping

Use line-based diff to map cursor position through changes:

1. Convert old cursor position to (line, column)
2. Compute line-level diff between old and new content
3. Map old line number through diff to find new line
4. Clamp column to new line length
5. Convert back to absolute position

Line-based diffing is appropriate because:
- Formatters typically work on whole lines
- Git operations are line-oriented
- Simpler than character-level diff
- Matches user's mental model of "same line"

## Implementation Details

**Files to modify:**
- `editors/sc-ide/core/doc_manager.cpp` - Add helper function and modify `reload()`
- `editors/sc-ide/core/doc_manager.hpp` - Declare helper function (private)

### Helper Function: mapCursorPosition

Add to `doc_manager.cpp` (as a static helper or private method):

```cpp
namespace {

struct LineCol {
    int line;   // 0-indexed
    int column; // 0-indexed
};

// Convert absolute position to line/column
LineCol positionToLineCol(const QString& content, int position) {
    int line = 0;
    int lineStart = 0;

    for (int i = 0; i < position && i < content.length(); ++i) {
        if (content[i] == '\n') {
            ++line;
            lineStart = i + 1;
        }
    }

    return { line, position - lineStart };
}

// Convert line/column to absolute position
int lineColToPosition(const QString& content, int line, int column) {
    int currentLine = 0;
    int pos = 0;

    while (pos < content.length() && currentLine < line) {
        if (content[pos] == '\n') {
            ++currentLine;
        }
        ++pos;
    }

    // Now at start of target line, add column (clamped to line length)
    int lineEnd = content.indexOf('\n', pos);
    if (lineEnd == -1) {
        lineEnd = content.length();
    }
    int lineLength = lineEnd - pos;

    return pos + qMin(column, lineLength);
}

// Count lines in content
int countLines(const QString& content) {
    int count = 1;
    for (int i = 0; i < content.length(); ++i) {
        if (content[i] == '\n') {
            ++count;
        }
    }
    return count;
}

// Simple line-based diff: returns mapping from old line numbers to new line numbers
// Uses longest common subsequence approach on lines
QVector<int> computeLineMapping(const QStringList& oldLines, const QStringList& newLines) {
    int oldCount = oldLines.size();
    int newCount = newLines.size();

    // Build LCS table
    QVector<QVector<int>> lcs(oldCount + 1, QVector<int>(newCount + 1, 0));
    for (int i = 1; i <= oldCount; ++i) {
        for (int j = 1; j <= newCount; ++j) {
            if (oldLines[i - 1] == newLines[j - 1]) {
                lcs[i][j] = lcs[i - 1][j - 1] + 1;
            } else {
                lcs[i][j] = qMax(lcs[i - 1][j], lcs[i][j - 1]);
            }
        }
    }

    // Backtrack to find mapping: oldLine -> newLine (-1 if deleted)
    QVector<int> mapping(oldCount, -1);
    int i = oldCount, j = newCount;
    while (i > 0 && j > 0) {
        if (oldLines[i - 1] == newLines[j - 1]) {
            mapping[i - 1] = j - 1;
            --i;
            --j;
        } else if (lcs[i - 1][j] >= lcs[i][j - 1]) {
            --i;  // Line was deleted
        } else {
            --j;  // Line was inserted
        }
    }

    return mapping;
}

// Map cursor position from old content to new content
int mapCursorPosition(const QString& oldContent, const QString& newContent, int oldPosition) {
    // Edge case: empty new content
    if (newContent.isEmpty()) {
        return 0;
    }

    // Edge case: position beyond old content
    if (oldPosition >= oldContent.length()) {
        oldPosition = qMax(0, oldContent.length() - 1);
    }

    // Convert to line/column
    LineCol oldLC = positionToLineCol(oldContent, oldPosition);

    // Split into lines
    QStringList oldLines = oldContent.split('\n');
    QStringList newLines = newContent.split('\n');

    // Compute line mapping
    QVector<int> lineMapping = computeLineMapping(oldLines, newLines);

    int newLine;
    if (oldLC.line < lineMapping.size() && lineMapping[oldLC.line] >= 0) {
        // Line survived (exact match): use mapped line
        newLine = lineMapping[oldLC.line];
    } else {
        // Line wasn't matched by LCS. Two possibilities:
        // 1. In-place reformat: line content changed but surrounding lines are stable
        // 2. Deletion: line was removed, other lines shifted

        // Detect in-place reformat: check if neighboring lines map to same positions
        // Only consider it a reformat if ALL matched neighbors stayed in place
        bool looksLikeReformat = false;
        if (oldLC.line < newLines.size()) {
            bool hasPrevNeighbor = (oldLC.line > 0
                                    && oldLC.line - 1 < lineMapping.size()
                                    && lineMapping[oldLC.line - 1] >= 0);
            bool hasNextNeighbor = (oldLC.line + 1 < lineMapping.size()
                                    && lineMapping[oldLC.line + 1] >= 0);

            // A neighbor is "stable" if it doesn't exist OR it maps to the same position
            bool prevStable = !hasPrevNeighbor
                              || (lineMapping[oldLC.line - 1] == oldLC.line - 1);
            bool nextStable = !hasNextNeighbor
                              || (lineMapping[oldLC.line + 1] == oldLC.line + 1);

            // Reformat only if we have at least one neighbor AND all neighbors are stable
            looksLikeReformat = (hasPrevNeighbor || hasNextNeighbor)
                                && prevStable && nextStable;
        }

        if (looksLikeReformat) {
            // In-place reformat: stay on same line number
            newLine = oldLC.line;
        } else {
            // Line was deleted: find nearest surviving line
            // Search backward first, then forward
            newLine = -1;
            for (int delta = 1; delta < qMax(oldLC.line + 1, oldLines.size() - oldLC.line); ++delta) {
                if (oldLC.line - delta >= 0 && lineMapping[oldLC.line - delta] >= 0) {
                    newLine = lineMapping[oldLC.line - delta];
                    break;
                }
                if (oldLC.line + delta < lineMapping.size() && lineMapping[oldLC.line + delta] >= 0) {
                    newLine = lineMapping[oldLC.line + delta];
                    break;
                }
            }
            // If still not found, default to last line
            if (newLine < 0) {
                newLine = newLines.size() - 1;
            }
        }
    }

    // Convert back to position, clamping column to new line length
    return lineColToPosition(newContent, newLine, oldLC.column);
}

} // anonymous namespace
```

### Modified reload() Method

```cpp
bool DocumentManager::reload(Document* doc) {
    Q_ASSERT(doc);

    if (doc->mFilePath.isEmpty())
        return false;

    QFile file(doc->mFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        MainWindow::instance()->showStatusMessage(tr("Cannot open file for reading: %1").arg(doc->mFilePath));
        return false;
    }

    QByteArray bytes(file.readAll());
    file.close();

    QString newContent = decodeDocument(bytes);

    // Save cursor and scroll state from active editor
    GenericCodeEditor* editor = doc->lastActiveEditor();
    int oldCursorPosition = -1;
    int scrollPosition = -1;
    QString oldContent;

    if (editor) {
        oldCursorPosition = editor->textCursor().position();
        scrollPosition = editor->verticalScrollBar()->value();
        oldContent = doc->mDoc->toPlainText();
    }

    doc->mDoc->setPlainText(newContent);
    doc->mDoc->setModified(false);

    // Restore cursor position using diff-based mapping
    if (editor && oldCursorPosition >= 0) {
        int newCursorPosition = mapCursorPosition(oldContent, newContent, oldCursorPosition);

        QTextCursor cursor(doc->mDoc);
        cursor.setPosition(newCursorPosition);
        editor->setTextCursor(cursor);

        if (scrollPosition >= 0) {
            editor->verticalScrollBar()->setValue(scrollPosition);
        }
    }

    QFileInfo info(doc->mFilePath);
    doc->mSaveTime = info.lastModified();

    if (!mFsWatcher.files().contains(doc->mFilePath))
        mFsWatcher.addPath(doc->mFilePath);

    return true;
}
```

### Alternative Strategies (for future consideration)

If diff-based matching proves insufficient, the modular design allows easy substitution:

**Strategy 1: Context Matching**
```cpp
int mapCursorPositionByContext(const QString& oldContent, const QString& newContent, int oldPosition) {
    // Extract N chars before/after cursor as context
    QString context = oldContent.mid(qMax(0, oldPosition - 20), 40);
    int found = newContent.indexOf(context);
    if (found >= 0) {
        return found + 20; // Cursor was 20 chars into context
    }
    // Fallback to simple clamp
    return qMin(oldPosition, newContent.length());
}
```

**Strategy 2: Simple Clamp (fallback)**
```cpp
int mapCursorPositionSimple(const QString& oldContent, const QString& newContent, int oldPosition) {
    Q_UNUSED(oldContent);
    return qMin(oldPosition, qMax(0, newContent.length() - 1));
}
```

## Testing

### Unit Tests for mapCursorPosition

```cpp
// Test: Lines inserted before cursor - cursor follows its line
void testLinesInsertedBefore() {
    QString old = "line1\nline2\nline3";
    QString new_ = "new1\nnew2\nline1\nline2\nline3";
    int oldPos = 12; // Start of "line3" (line 2, col 0)
    int newPos = mapCursorPosition(old, new_, oldPos);
    // "line3" moved from line 2 to line 4, position 22
    // new1(4) + \n + new2(4) + \n + line1(5) + \n + line2(5) + \n = 22
    QCOMPARE(newPos, 22);
}

// Test: Line deleted - cursor moves to nearest surviving line, preserving column
void testLineDeleted() {
    QString old = "line1\nline2\nline3";
    QString new_ = "line1\nline3";
    int oldPos = 8; // Middle of "line2" (line 1, col 2)
    int newPos = mapCursorPosition(old, new_, oldPos);
    // line2 deleted, nearest surviving line is line1 (backward search)
    // Column 2 preserved -> position 2
    QCOMPARE(newPos, 2);
}

// Test: Line reformatted in place - cursor stays on same line
void testLineReformatted() {
    QString old = "short\nline2";
    QString new_ = "much longer line now\nline2";
    int oldPos = 3; // Column 3 of "short" (line 0, col 3)
    int newPos = mapCursorPosition(old, new_, oldPos);
    // "line2" stayed at line 1, so "short"->"much longer" is in-place reformat
    // Cursor stays at line 0, column 3
    QCOMPARE(newPos, 3);
}

// Test: Identical content - position unchanged
void testNoChange() {
    QString content = "line1\nline2\nline3";
    int pos = 8;
    QCOMPARE(mapCursorPosition(content, content, pos), pos);
}

// Test: Column clamped when line gets shorter
void testColumnClamped() {
    QString old = "very long line here\nline2";
    QString new_ = "short\nline2";
    int oldPos = 15; // Column 15 of first line
    int newPos = mapCursorPosition(old, new_, oldPos);
    // First line is now only 5 chars, column clamped to 5
    QCOMPARE(newPos, 5);
}

// Test: Lines deleted at end
void testLinesDeletedAtEnd() {
    QString old = "line1\nline2\nline3\nline4";
    QString new_ = "line1\nline2";
    int oldPos = 18; // Start of "line4" (line 3, col 0)
    int newPos = mapCursorPosition(old, new_, oldPos);
    // line3 and line4 deleted, nearest surviving is line2 (new line 1)
    // Backward search: line3 (no match) -> line2 (match at new line 1)
    // Position at new line 1, col 0 = 6
    QCOMPARE(newPos, 6);
}
```

### Integration Tests

1. Open a file in SCIDE with `autoReloadExternalChanges` enabled
2. Position cursor at line 50, column 10
3. Externally run a formatter that adds 5 lines at the top
4. Verify cursor is now at line 55, column 10 (or nearest valid position)

Additional scenarios:
- Formatter deletes the cursor's line entirely
- Formatter rewrites cursor's line (shorter/longer)
- Git checkout replaces file with completely different content
- File is truncated to 0 bytes

## Files to Modify

| File | Change |
|------|--------|
| `editors/sc-ide/core/doc_manager.cpp` | Add `mapCursorPosition()` helper, modify `reload()` |
| `editors/sc-ide/core/doc_manager.hpp` | (Optional) Declare helper if making it a class method |

## Dependencies

None - uses only Qt's QString/QStringList and standard algorithms.

## Edge Cases Handled

| Edge Case | Handling |
|-----------|----------|
| No active editor | Skip cursor preservation |
| Empty new content | Return position 0 |
| Lines inserted before cursor | LCS maps old line to new position, cursor follows |
| Cursor line deleted | Find nearest surviving line (backward first), preserve column |
| Cursor line reformatted in place | Detect via stable neighbors, stay on same line number |
| Cursor column exceeds new line length | Clamp to end of line |
| All content replaced | Best-effort via LCS, fallback to last line |
| Identical content | Returns same position (LCS exact match) |

## Algorithm Complexity

- **Time**: O(M × N) for LCS table where M and N are line counts
- **Space**: O(M × N) for LCS table, O(M) for line mapping

For typical source files (< 10,000 lines), this is negligible. For very large files, consider:
- Early exit if content is identical (string comparison)
- Limit LCS to lines around cursor position (sliding window)

## Strategy Swap Guide

The `mapCursorPosition` function is the single point of customization. To swap strategies:

1. Rename current function to `mapCursorPositionLCS`
2. Create new implementation with same signature
3. Update call site in `reload()` to use new function

Alternative strategies to consider if LCS proves insufficient:
- **Context matching**: Search for text surrounding old cursor position
- **Hybrid**: Use LCS for structural changes, context for in-place edits
- **Line hash buckets**: Group identical lines, resolve ambiguity by proximity
