# SCIDE - Fix Cmd+Backspace / Cmd+Delete Shortcuts on macOS

**Date:** 2026-01-10 22:52:32
**Issue:** Cmd+Backspace and Cmd+Delete do nothing on macOS due to incorrect modifier key check
**Priority:** Medium
**Status:** Requires Implementation

## Problem Statement

- On macOS, Cmd+Backspace should delete from cursor to beginning of line
- On macOS, Cmd+Delete should delete from cursor to end of line
- Currently, neither shortcut works - they do nothing
- The functionality exists but is bound to the wrong modifier key

## Root Cause Analysis

In `editors/sc-ide/widgets/code_editor/editor.cpp`, the key handlers check for `Qt::META`:

```cpp
// editor.cpp:579-582
void GenericCodeEditor::handleKeyBackspace(QKeyEvent* event, QTextCursor& textCursor, bool& updateCursor) {
    if (event->modifiers() & Qt::META) {  // BUG: Qt::META = Control key on macOS
        textCursor.movePosition(QTextCursor::StartOfBlock, QTextCursor::KeepAnchor);
        textCursor.removeSelectedText();
    }
```

```cpp
// editor.cpp:571-576
void GenericCodeEditor::handleKeyDelete(QKeyEvent* event, QTextCursor& textCursor) {
    if (event->modifiers() & Qt::META) {  // BUG: Qt::META = Control key on macOS
        textCursor.movePosition(QTextCursor::EndOfBlock, QTextCursor::KeepAnchor);
        textCursor.removeSelectedText();
    }
```

Qt's macOS key mapping (see [Qt docs](https://doc.qt.io/qt-6/qkeysequence.html)):

| Qt Modifier | macOS Key | Windows/Linux Key |
|-------------|-----------|-------------------|
| `Qt::CTRL` | Command (⌘) | Ctrl |
| `Qt::META` | Control (⌃) | Win |

The code uses `Qt::META`, so on macOS it responds to **Control+Backspace** instead of **Cmd+Backspace**.

## Technical Approach

Change `Qt::META` to `Qt::CTRL` in both handlers. This makes:
- **macOS:** Cmd+Backspace and Cmd+Delete work as expected
- **Windows/Linux:** Ctrl+Backspace and Ctrl+Delete trigger these actions

Note: On Windows/Linux, Ctrl+Backspace conventionally means "delete word". This change overrides that convention, but SCIDE already has its own keyboard conventions.

## Implementation Details

### Step 1: Fix handleKeyBackspace

**File:** `editors/sc-ide/widgets/code_editor/editor.cpp:580`

Change:
```cpp
if (event->modifiers() & Qt::META) {
```

To:
```cpp
if (event->modifiers() & Qt::CTRL) {
```

### Step 2: Fix handleKeyDelete

**File:** `editors/sc-ide/widgets/code_editor/editor.cpp:572`

Change:
```cpp
if (event->modifiers() & Qt::META) {
```

To:
```cpp
if (event->modifiers() & Qt::CTRL) {
```

### Testing

1. Build SCIDE:
   ```bash
   cd build
   /Applications/CMake.app/Contents/bin/cmake --build . -j$(sysctl -n hw.ncpu) && /Applications/CMake.app/Contents/bin/cmake --build . --target install
   ```

2. Open SuperCollider.app and create a document with test text:
   ```
   This is a test line
   ```

3. Test Cmd+Backspace:
   - Position cursor in middle of line
   - Press Cmd+Backspace
   - Verify text from cursor to beginning of line is deleted

4. Test Cmd+Delete:
   - Position cursor in middle of line
   - Press Cmd+Delete
   - Verify text from cursor to end of line is deleted

5. Test edge cases:
   - Cursor at beginning of line (Cmd+Backspace should do nothing)
   - Cursor at end of line (Cmd+Delete should do nothing)
   - With text selected (should delete selection and text to line boundary)

6. Verify undo (Cmd+Z) restores deleted text
