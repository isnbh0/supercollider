# Cmd+Backspace and Cmd+Delete Broken on macOS Since 2012

**Date**: 2026-01-10 23:06:23
**Commit Hash**: 6760db0772f067db66bf812109a90302e86b7a90
**Analysis Scope**: Investigation of non-functional Cmd+Backspace (delete to beginning of line) and Cmd+Delete (delete to end of line) shortcuts in SCIDE on macOS

## Executive Summary

The SCIDE editor has had broken Cmd+Backspace and Cmd+Delete shortcuts on macOS for over 13 years. The feature was implemented in September 2012 but uses the wrong Qt modifier key constant. The code checks for `Qt::META` (which maps to the Control key on macOS) instead of `Qt::CTRL` (which maps to the Command key on macOS). This is a two-line fix.

No existing GitHub issue was found for this bug, despite it affecting a standard macOS text editing shortcut that users reasonably expect to work.

## Key Findings

1. **The feature exists but is bound to the wrong key**
   - `handleKeyBackspace()` in `editor.cpp:579-582` checks for `Qt::META`
   - `handleKeyDelete()` in `editor.cpp:571-576` checks for `Qt::META`
   - On macOS, `Qt::META` corresponds to the Control key (⌃), not Command (⌘)

2. **Qt's macOS key mapping is counterintuitive**

   | Qt Modifier | macOS Key | Windows/Linux Key |
   |-------------|-----------|-------------------|
   | `Qt::CTRL`  | Command (⌘) | Ctrl |
   | `Qt::META`  | Control (⌃) | Win |
   | `Qt::ALT`   | Option (⌥) | Alt |

3. **Bug introduced in commit `0645264` (September 18, 2012)**
   ```
   Author: Tim Blechmann <tim@klingt.org>
   Date:   Tue Sep 18 12:18:46 2012 +0200

       scide: provide shortcut for deleting start/end of line
   ```
   The commit message indicates the intent was to provide these shortcuts, but the implementation used the wrong modifier.

4. **Current actual behavior**
   - Control+Backspace → deletes to beginning of line (unintended binding)
   - Control+Delete → deletes to end of line (unintended binding)
   - Cmd+Backspace → does nothing (broken)
   - Cmd+Delete → does nothing (broken)

## Root Cause Analysis

The root cause is a misunderstanding of Qt's platform-specific key mapping. Qt intentionally swaps `Ctrl` and `Meta` on macOS so that cross-platform code using `Ctrl+C` for copy works correctly on both platforms (Ctrl on Windows/Linux, Cmd on macOS).

This design decision, while beneficial for cross-platform shortcuts, creates confusion when developers explicitly handle key events and check modifiers directly.

**Affected code in `editors/sc-ide/widgets/code_editor/editor.cpp`:**

```cpp
// Line 571-576
void GenericCodeEditor::handleKeyDelete(QKeyEvent* event, QTextCursor& textCursor) {
    if (event->modifiers() & Qt::META) {  // BUG: Should be Qt::CTRL
        textCursor.movePosition(QTextCursor::EndOfBlock, QTextCursor::KeepAnchor);
        textCursor.removeSelectedText();
    } else
        QPlainTextEdit::keyPressEvent(event);
}

// Line 579-590
void GenericCodeEditor::handleKeyBackspace(QKeyEvent* event, QTextCursor& textCursor, bool& updateCursor) {
    if (event->modifiers() & Qt::META) {  // BUG: Should be Qt::CTRL
        textCursor.movePosition(QTextCursor::StartOfBlock, QTextCursor::KeepAnchor);
        textCursor.removeSelectedText();
    } else {
        // ... normal backspace handling
    }
}
```

**Why this wasn't caught:**
- The feature still "works" with Control+Backspace/Delete
- Control+Backspace isn't a common shortcut on macOS, so users may not have noticed
- Cmd+Backspace doing nothing might have seemed like "not implemented" rather than "broken"
- The Qt Ctrl/Meta swap is not well-known

## Recommendations

### 1. Fix the Bug (Two-Line Change)

Change `Qt::META` to `Qt::CTRL` in both locations:

**File:** `editors/sc-ide/widgets/code_editor/editor.cpp`

```cpp
// Line 572: Change
if (event->modifiers() & Qt::META) {
// To:
if (event->modifiers() & Qt::CTRL) {

// Line 580: Change
if (event->modifiers() & Qt::META) {
// To:
if (event->modifiers() & Qt::CTRL) {
```

### 2. Cross-Platform Impact Analysis

After this fix:
- **macOS:** Cmd+Backspace and Cmd+Delete will work as expected
- **Windows/Linux:** Ctrl+Backspace and Ctrl+Delete will trigger "delete to beginning/end of line"

#### Will This Break Windows/Linux?

**Yes, it changes behavior.** On Windows and Linux, Ctrl+Backspace is a [widely standardized shortcut for "delete previous word"](https://amazingalgorithms.com/definitions/ctrlbackspace/). This convention dates back to early word processors like WordStar and is now standard in:
- Microsoft Word and Office applications
- Most IDEs (VS Code, IntelliJ, etc.)
- Web browsers (text fields)
- GTK and Qt applications by default

Qt's [QPlainTextEdit](https://doc.qt.io/qt-6/qplaintextedit.html) (which SCIDE's editor inherits from) provides Ctrl+Backspace "delete word" behavior by default. However, SCIDE's `handleKeyBackspace()` intercepts the key event before Qt can handle it.

#### Current Behavior (Before Fix)

| Platform | Ctrl+Backspace | Behavior |
|----------|----------------|----------|
| macOS | Control+Backspace | Delete to beginning of line (via `Qt::META` check) |
| Windows | Ctrl+Backspace | Delete to beginning of line (via `Qt::META` = Win key, but event not triggered) |
| Linux | Ctrl+Backspace | Delete to beginning of line (via `Qt::META` = Win/Super key, but event not triggered) |

**Note:** On Windows/Linux, `Qt::META` corresponds to the Win/Super key, which users rarely press with Backspace. So effectively, the feature is **unreachable** on Windows/Linux currently.

#### Behavior After Fix

| Platform | Shortcut | New Behavior | Convention Impact |
|----------|----------|--------------|-------------------|
| macOS | Cmd+Backspace | Delete to beginning of line | ✓ Matches macOS convention |
| Windows | Ctrl+Backspace | Delete to beginning of line | ✗ Overrides "delete word" convention |
| Linux | Ctrl+Backspace | Delete to beginning of line | ✗ Overrides "delete word" convention |

#### Recommendation: Accept the Change

**Reasons to proceed without platform guards:**

1. **Current state is broken everywhere** - The feature doesn't work properly on any platform right now
2. **SCIDE has its own conventions** - It already deviates from platform norms in other shortcuts
3. **"Delete word" is still available** - Users can use Option+Backspace (macOS) or may have other methods; Qt may still handle unmodified cases
4. **Consistency** - Same shortcut works the same way on all platforms (Ctrl/Cmd+Backspace = delete to line start)

#### Alternative: Platform-Specific Behavior

If strict adherence to platform conventions is desired:

```cpp
#ifdef Q_OS_MAC
if (event->modifiers() & Qt::CTRL) {  // Cmd on macOS
#else
if (event->modifiers() & Qt::META) {  // Keep Win+Backspace on Windows/Linux (rarely used)
#endif
```

This preserves the (broken) Win+Backspace binding on Windows/Linux while fixing macOS, but means the feature remains effectively unusable on Windows/Linux.

#### Sources

- [Ctrl+Backspace Definition](https://amazingalgorithms.com/definitions/ctrlbackspace/) - Standard behavior across platforms
- [Qt QPlainTextEdit Documentation](https://doc.qt.io/qt-6/qplaintextedit.html) - Default key bindings
- [Qt QKeySequence Documentation](https://doc.qt.io/qt-6/qkeysequence.html) - Ctrl/Meta swap explanation
- [OpenOffice Forum Discussion](https://forum.openoffice.org/en/forum/viewtopic.php?t=101193) - User expectations for Ctrl+Backspace

### 3. Path to Contribution

**Step 1: File a GitHub Issue**
```
Title: [Bug] Cmd+Backspace and Cmd+Delete don't work on macOS

The shortcuts for "delete to beginning of line" (Cmd+Backspace) and
"delete to end of line" (Cmd+Delete) do not work on macOS.

Root cause: The code in editor.cpp checks for Qt::META instead of Qt::CTRL.
On macOS, Qt maps Ctrl→Cmd and Meta→Control, so the feature is currently
bound to Control+Backspace/Delete instead of Cmd+Backspace/Delete.

This bug has existed since the feature was added in commit 0645264 (2012).
```

**Step 2: Fork and Clone**
```bash
gh repo fork supercollider/supercollider --clone
cd supercollider
git checkout -b fix/macos-cmd-backspace-delete
```

**Step 3: Make the Fix**
```bash
# Edit editors/sc-ide/widgets/code_editor/editor.cpp
# Change Qt::META to Qt::CTRL on lines 572 and 580
```

**Step 4: Build and Test**
```bash
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DSC_USE_QTWEBENGINE=OFF ..
cmake --build . -j$(sysctl -n hw.ncpu)
cmake --build . --target install
open Install/SuperCollider/SuperCollider.app
# Test Cmd+Backspace and Cmd+Delete in the editor
```

**Step 5: Commit and Push**
```bash
git add editors/sc-ide/widgets/code_editor/editor.cpp
git commit -m "fix(scide): use correct modifier for Cmd+Backspace/Delete on macOS

The shortcuts for delete-to-beginning-of-line (Cmd+Backspace) and
delete-to-end-of-line (Cmd+Delete) were checking for Qt::META instead
of Qt::CTRL. On macOS, Qt maps Ctrl to Command and Meta to Control,
so these shortcuts were bound to the wrong physical keys.

Fixes #XXXX"
git push origin fix/macos-cmd-backspace-delete
```

**Step 6: Open Pull Request**
```bash
gh pr create --title "fix(scide): use correct modifier for Cmd+Backspace/Delete on macOS" \
  --body "## Summary
- Fixes Cmd+Backspace (delete to beginning of line) on macOS
- Fixes Cmd+Delete (delete to end of line) on macOS

## Root Cause
Code checked \`Qt::META\` instead of \`Qt::CTRL\`. On macOS, Qt swaps these modifiers.

## Testing
- [x] Tested Cmd+Backspace deletes to beginning of line
- [x] Tested Cmd+Delete deletes to end of line
- [x] Tested undo restores deleted text

Fixes #XXXX"
```

### 4. Prevent Future Issues

Add the Qt macOS key mapping reference to developer documentation (already added to `CLAUDE.md` in this session). Consider adding to `CONTRIBUTING.md` or a developer wiki page.

## Related Resources

- [Qt QKeySequence Documentation](https://doc.qt.io/qt-6/qkeysequence.html) - Explains the Ctrl/Meta swap on macOS
- Commit `0645264` - Original implementation with the bug
- Spec file: `workspace/specs/260110-225232-delete-to-beginning-of-line-shortcut.md`
