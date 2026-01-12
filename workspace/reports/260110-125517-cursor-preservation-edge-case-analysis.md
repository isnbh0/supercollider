# Edge Case Analysis: Preserve Cursor Position on Auto-Reload Spec

**Date**: 2026-01-10 12:55:17 (Updated: 2026-01-10 12:57:00)
**Commit Hash**: 5f5c6422d80daa91e296469613765da0fb2cfe63
**Analysis Scope**: Edge case identification and coverage assessment for cursor preservation during auto-reload

## Executive Summary

The spec for preserving cursor position on auto-reload (`260110-125023-preserve-cursor-on-reload.md`) has been updated to use a **diff-based LCS (Longest Common Subsequence) algorithm** with a modular architecture. The implementation now handles the critical edge case of content changing before/around the cursor position.

**Overall Assessment**: The updated spec handles ~90% of edge cases through LCS line mapping with intelligent fallback for reformatted lines. The modular design (`mapCursorPosition` function) allows easy strategy substitution if the LCS approach proves insufficient.

## Key Findings

1. **Fully Covered Edge Cases** - The updated spec handles:
   - No active editor (skip preservation entirely)
   - Empty document after reload (return position 0)
   - Lines inserted before cursor (LCS maps old line to new position)
   - Lines deleted (find nearest surviving line via backward search)
   - Cursor line reformatted in place (detect via stable neighbors)
   - Column exceeds new line length (clamp to end of line)

2. **Partially Covered Edge Cases**:
   - Multiple editors viewing same document (only `lastActiveEditor` preserved)

3. **Remaining Uncovered Edge Cases**:
   - Text selection preservation (only cursor position, not anchor)
   - Concurrent modification during reload (unlikely but possible)
   - Undo stack clearing (Qt behavior, outside scope)

## Root Cause Analysis

### The Core Algorithm: LCS-Based Line Mapping

The updated spec uses a three-tier approach:

**Tier 1: Exact Line Match via LCS**
```cpp
if (oldLC.line < lineMapping.size() && lineMapping[oldLC.line] >= 0) {
    // Line survived (exact match): use mapped line
    newLine = lineMapping[oldLC.line];
}
```
When a line's content is unchanged, LCS maps it to its new position. This handles insertions/deletions before the cursor.

**Tier 2: In-Place Reformat Detection**
```cpp
bool looksLikeReformat = (hasPrevNeighbor || hasNextNeighbor)
                        && prevStable && nextStable;
if (looksLikeReformat) {
    newLine = oldLC.line; // Stay on same line number
}
```
When a line's content changed but ALL neighboring lines stayed in their same positions, it's an in-place edit. The cursor stays on the same line number.

**Tier 3: Deleted Line Fallback**
```cpp
// Search backward first, then forward for nearest surviving line
for (int delta = 1; ...) {
    if (lineMapping[oldLC.line - delta] >= 0) {
        newLine = lineMapping[oldLC.line - delta];
        break;
    }
}
```
When the cursor's line was deleted and lines shifted, find the nearest surviving line.

### Edge Cases Partially Covered

**4. Multiple Editors Viewing Same Document**

The spec notes this in testing: "Multiple editors viewing same document: cursor preserved in active editor"

However, the implementation only uses `lastActiveEditor()`. If Document A is open in Tab 1 and Tab 2:
- User is typing in Tab 2 (making it "last active")
- User switches to Tab 1, positions cursor at line 100
- External change occurs
- Reload uses Tab 2's editor (the "last active" one)
- Tab 1's cursor is not preserved

**Current spec coverage**: Minimal. The `lastActiveEditor` pattern works for the common single-editor case but breaks for split views.

**Potential enhancement**: Iterate all editors via a document-to-editor mapping (if one exists) and restore each editor's state.

### Edge Cases Not Covered

**5. Text Selection Preservation**

The current approach only saves `cursor.position()`, which is the cursor's end point. A text selection has two positions:
- `position()` - where the cursor is
- `anchor()` - where the selection started

If a user has lines 50-100 selected and an external change occurs, the selection will be lost entirely.

```cpp
// Not in spec - would require:
int anchorPosition = editor->textCursor().anchor();
// ... after reload ...
cursor.setPosition(clampedAnchor);
cursor.setPosition(clampedPosition, QTextCursor::KeepAnchor);
```

**Severity**: Medium. Users actively selecting code during external changes is uncommon but not impossible (e.g., preparing to copy while a formatter runs).

**6. Character Position vs. Line/Column Semantics**

The spec uses absolute character position. Consider:
- User cursor at line 50, column 10 (absolute position 1200)
- External change adds 500 characters at line 10
- After reload, position 1200 points to line 45, column 10

The cursor "moved" relative to the visible line structure. An alternative approach would preserve line and column numbers instead:
- Save line 50, column 10
- After reload, restore to line 50, column 10 (or clamped)

**Current spec approach**: Character-based (simpler, matches existing `onDocumentSaved()` pattern)
**Alternative**: Line/column-based (more intuitive for large structural changes)
**Tradeoff**: The spec's choice is reasonable for the common case (minor formatting changes). Line-based would be better for large refactors but adds complexity.

**7. Concurrent Modification During Reload**

Timeline:
1. User at position 500
2. External change detected, reload starts
3. User types before `setPlainText()` completes (unlikely but possible)
4. Saved position (500) is now stale

Qt's event loop typically prevents this since `reload()` should be synchronous and the editor blocked, but it's worth noting as an implicit assumption.

**8. Editor Visibility and Focus State**

If the editor widget is not visible (document in a background tab):
- `verticalScrollBar()->value()` may return stale data
- The scroll position saved may not match what the user last saw

**Current spec coverage**: None. Assumes the editor state is valid.
**Practical impact**: Low. Background tabs typically have reasonable cached state.

**9. File Encoding Changes**

If an external tool saves the file with a different encoding:
- `decodeDocument()` may interpret bytes differently
- Character count could change unpredictably
- Position clamping handles this, but cursor lands at "wrong" location

**Current spec coverage**: Implicit via clamping.
**Practical impact**: Very low (encoding changes are rare).

**10. Undo Stack State**

After `setPlainText()`, the undo stack is cleared (Qt behavior). The spec doesn't address:
- Should undo history be preserved?
- Should the reload itself be undoable?

**Current spec coverage**: None (outside scope).
**Practical impact**: Medium. Users may expect Ctrl+Z to undo external changes.

## Recommendations

1. **Implement as specified** - The current spec handles the most common cases well
   - Single editor, minor external changes, cursor within bounds
   - The clamping logic is correct and follows existing patterns

2. **Consider selection preservation as a follow-up**
   - Add `anchor()` saving alongside `position()`
   - Low implementation cost, noticeable UX improvement
   - Priority: Medium

3. **Document the multi-editor limitation**
   - Add a comment in code noting that only `lastActiveEditor` is restored
   - Consider filing a separate enhancement for split view support
   - Priority: Low (rare use case)

4. **Do not pursue line/column semantics**
   - Character-based approach matches existing patterns
   - Complexity increase not justified for this use case
   - The "cursor moved relative to lines" scenario is rare

5. **Test with actual formatters**
   - The spec lists `echo "// comment" >> file.scd` as a test
   - Should also test with real formatters that modify throughout the file
   - Verify clamping behavior is acceptable for significant restructuring

## Related Analysis

- Parent spec: `260110-121030-auto-reload-external-changes.md` (Completed)
- Existing pattern: `CodeEditorBox::onDocumentSaved()` at `editor_box.cpp:185-200`
