# SCIDE - Auto-Reload External File Changes Setting

**Date:** 2026-01-10 12:10:30
**Issue:** No option to automatically reload files modified externally without user confirmation
**Priority:** Medium
**Status:** Completed
**Completed:** 2026-01-10

## Problem Statement

- **Current behavior**: When a file open in SCIDE is modified by an external program (e.g., another text editor), SCIDE shows a dialog asking the user to choose between Reload, Overwrite, Ignore, or Close.
- **Expected behavior**: Users should have an option to automatically reload files from disk when external changes are detected, similar to VSCode's default behavior.
- **Impact**: Users who edit SuperCollider files with external tools (vim, VSCode, etc.) must manually dismiss the dialog for each file change, disrupting their workflow.

## Root Cause Analysis

The external change detection flow works as follows:

1. `QFileSystemWatcher` monitors all open file paths (`doc_manager.cpp:259`)
2. When a file changes, `DocumentManager::onFileChanged()` is called (`doc_manager.cpp:538-551`)
3. If the file's modification time is newer than the recorded save time, `changedExternally` signal is emitted
4. `MainWindow::onDocumentChangedExternally()` unconditionally shows the `DocumentsDialog` (`main_window.cpp:840-848`)

```cpp
// editors/sc-ide/core/doc_manager.cpp:538-551
void DocumentManager::onFileChanged(const QString& path) {
    DocIterator it;
    for (it = mDocHash.begin(); it != mDocHash.end(); ++it) {
        Document* doc = it.value();
        if (doc->mFilePath == path) {
            QFileInfo info(doc->mFilePath);
            if (doc->mSaveTime < info.lastModified()) {
                doc->mDoc->setModified(true);
                doc->mSaveTime = info.lastModified();
                emit changedExternally(doc);  // Always emits, no setting check
            }
        }
    }
}
```

There is no setting to control this behavior. The dialog is always shown.

## Technical Approach

Add a new boolean setting `IDE/editor/autoReloadExternalChanges` that, when enabled:
- Bypasses the confirmation dialog
- Automatically reloads the file from disk

This follows the existing settings pattern used by other editor preferences (e.g., `lineWrap`, `highlightBracketContents`).

## Implementation Details

### Step 1: Add Default Setting

**File:** `editors/sc-ide/core/settings/manager.cpp`

In `Manager::initDefaults()`, add the new setting inside the `IDE/editor` group (around line 71):

```cpp
// editors/sc-ide/core/settings/manager.cpp:71 (in initDefaults(), inside IDE/editor group)
setDefault("autoReloadExternalChanges", false);
```

### Step 2: Modify External Change Handler

**File:** `editors/sc-ide/core/doc_manager.cpp`

Modify `onFileChanged()` to check the setting and either reload automatically or emit the signal:

```cpp
// editors/sc-ide/core/doc_manager.cpp:538-551
void DocumentManager::onFileChanged(const QString& path) {
    DocIterator it;
    for (it = mDocHash.begin(); it != mDocHash.end(); ++it) {
        Document* doc = it.value();
        if (doc->mFilePath == path) {
            QFileInfo info(doc->mFilePath);
            if (doc->mSaveTime < info.lastModified()) {
                // Check if auto-reload is enabled
                bool autoReload = Main::settings()->value("IDE/editor/autoReloadExternalChanges").toBool();
                if (autoReload) {
                    reload(doc);
                } else {
                    doc->mDoc->setModified(true);
                    doc->mSaveTime = info.lastModified();
                    emit changedExternally(doc);
                }
            }
        }
    }
}
```

Note: The `reload()` method already handles setting `mSaveTime` and clearing the modified flag (`doc_manager.cpp:362-387`), so we don't need to set those manually when auto-reloading.

### Step 3: Add UI Checkbox to Editor Settings

**File:** `editors/sc-ide/forms/settings_editor.ui`

Add a checkbox widget to the Editor settings page. The checkbox should be placed in an appropriate location (likely near other editor behavior options). The widget should be named `autoReloadExternalChanges`.

**File:** `editors/sc-ide/widgets/settings/editor_page.hpp`

No changes needed if using the `ui` pointer pattern (the checkbox is accessed via `ui->autoReloadExternalChanges`).

**File:** `editors/sc-ide/widgets/settings/editor_page.cpp`

In `EditorPage::load()` (around line 81-95, inside the `IDE/editor` group):

```cpp
ui->autoReloadExternalChanges->setChecked(s->value("autoReloadExternalChanges").toBool());
```

In `EditorPage::store()` method, add:

```cpp
s->setValue("autoReloadExternalChanges", ui->autoReloadExternalChanges->isChecked());
```

### Step 4: Ensure Proper Include

**File:** `editors/sc-ide/core/doc_manager.cpp`

Verify that `#include "main.hpp"` is present at the top (it likely already is, but confirm for accessing `Main::settings()`).

## Testing Strategy

1. **Build and run SCIDE**
2. **Default behavior (setting OFF)**:
   - Open a file in SCIDE
   - Modify the file externally (e.g., `echo "// test" >> file.scd`)
   - Verify the "Externally Changed Documents" dialog appears
3. **Enable setting**:
   - Go to Edit > Preferences > Editor
   - Check "Auto-reload external changes" (or similar label)
   - Click OK
4. **Auto-reload behavior (setting ON)**:
   - Modify the same file externally
   - Verify NO dialog appears
   - Verify the file content in SCIDE is updated automatically
5. **Edge cases**:
   - Test with unsaved local changes (should still auto-reload and lose local changes when setting is ON - this is expected behavior matching VSCode)
   - Test with multiple files changed simultaneously
   - Test with file deletion (should still show dialog since auto-reload can't reload a deleted file)

## Files to Modify

| File | Change |
|------|--------|
| `editors/sc-ide/core/settings/manager.cpp` | Add default setting |
| `editors/sc-ide/core/doc_manager.cpp` | Check setting in `onFileChanged()` |
| `editors/sc-ide/forms/settings_editor.ui` | Add checkbox widget |
| `editors/sc-ide/widgets/settings/editor_page.cpp` | Load/store setting |

## Dependencies

None - uses existing Qt and SCIDE infrastructure.
