# SCIDE - Auto-Save After Delay Feature

**Date:** 2026-01-10 14:19:00
**Issue:** Add VS Code-style auto-save that saves documents after a configurable delay
**Priority:** Medium
**Status:** Completed
**Implementation:**
- Commit: b28ea746e - feat(scide): add auto-save after delay feature
**Completed:** 2026-01-10

## Problem Statement

- **Current behavior:** Documents are only saved when the user explicitly triggers save (Ctrl+S/Cmd+S or File > Save). Unsaved changes can be lost if the IDE crashes or the user forgets to save.
- **Expected behavior:** Documents with file paths should be automatically saved after a configurable period of inactivity (similar to VS Code's "afterDelay" mode).
- **Impact:** Reduces data loss risk and provides a more modern editing experience.

## Root Cause Analysis

The IDE currently has no auto-save to disk functionality. However, it does have a related feature that can serve as a design reference:

**Existing Auto-Backup Pattern** (`editors/sc-ide/core/doc_manager.cpp:355-408`):

```cpp
// Document::storeTmpFile() - coalesces changes before writing backup
if (++mTmpCoalCount < RESTORE_COAL) {  // RESTORE_COAL = 100
    mTmpCoalTimer.start();              // Reset 60-second single-shot timer
    return;
}
// Write backup to tmp directory
```

This pattern:
1. Counts content changes
2. Resets a single-shot timer on each change
3. After the timer fires (60s of inactivity), writes backup

The auto-save feature should follow a similar debounce pattern but:
- Write to the actual file (not a backup)
- Use a user-configurable delay
- Be toggleable via settings

**Recently Added Setting Pattern** - `autoReloadExternalChanges` (commit a63af9f88) demonstrates the complete 4-step pattern for adding editor settings.

## Technical Approach

Implement auto-save using the established debounce pattern from auto-backup:

1. Add a dedicated `QTimer` per `Document` for auto-save (separate from backup timer)
2. Reset the timer on each content change when auto-save is enabled
3. When the timer fires, call the existing `DocumentManager::save()` method
4. Only auto-save documents that have a file path (skip untitled documents)
5. Make feature configurable with enable/disable toggle and delay setting

**Why this approach:**
- Reuses proven debounce pattern already in the codebase
- Minimal new code - leverages existing save infrastructure
- Consistent with how VS Code's "afterDelay" works
- Low risk - adds new timer without modifying existing backup system

## Implementation Details

### Step 1: Add Settings Defaults

**File:** `editors/sc-ide/core/settings/manager.cpp`

Add to `Manager::initDefaults()` within the `editor` group (around line 72):

```cpp
// Auto-save settings
setDefault("autoSave", false);           // Disabled by default
setDefault("autoSaveDelay", 1000);       // 1 second delay (in milliseconds)
```

### Step 2: Add UI Controls

**File:** `editors/sc-ide/forms/settings_editor.ui`

Add a new group box for auto-save settings. Place after the "Reload" group (around line 70):

```xml
<item>
  <widget class="QGroupBox" name="autoSaveGroupBox">
    <property name="title">
      <string>Auto-Save</string>
    </property>
    <layout class="QVBoxLayout" name="autoSaveLayout">
      <item>
        <widget class="QCheckBox" name="autoSaveCheckBox">
          <property name="text">
            <string>Automatically save files after delay</string>
          </property>
        </widget>
      </item>
      <item>
        <layout class="QHBoxLayout" name="autoSaveDelayLayout">
          <item>
            <widget class="QLabel" name="autoSaveDelayLabel">
              <property name="text">
                <string>Delay:</string>
              </property>
            </widget>
          </item>
          <item>
            <widget class="QSpinBox" name="autoSaveDelaySpinBox">
              <property name="suffix">
                <string> ms</string>
              </property>
              <property name="minimum">
                <number>100</number>
              </property>
              <property name="maximum">
                <number>30000</number>
              </property>
              <property name="singleStep">
                <number>100</number>
              </property>
              <property name="value">
                <number>1000</number>
              </property>
            </widget>
          </item>
          <item>
            <spacer name="autoSaveDelaySpacer">
              <property name="orientation">
                <enum>Qt::Horizontal</enum>
              </property>
            </spacer>
          </item>
        </layout>
      </item>
    </layout>
  </widget>
</item>
```

### Step 3: Add Load/Store in EditorPage

**File:** `editors/sc-ide/widgets/settings/editor_page.cpp`

In `EditorPage::load()` (around line 138, near other editor settings):

```cpp
// Auto-save settings
ui->autoSaveCheckBox->setChecked(s->value("autoSave").toBool());
ui->autoSaveDelaySpinBox->setValue(s->value("autoSaveDelay").toInt());
```

In `EditorPage::store()` (around line 285, near other editor settings):

```cpp
// Auto-save settings
s->setValue("autoSave", ui->autoSaveCheckBox->isChecked());
s->setValue("autoSaveDelay", ui->autoSaveDelaySpinBox->value());
```

### Step 4: Add Auto-Save Timer to Document Class

**File:** `editors/sc-ide/core/doc_manager.hpp`

Add private members to `Document` class (around line 140):

```cpp
private:
    // Auto-save timer (debounces saves after delay)
    QTimer mAutoSaveTimer;
    void setupAutoSave();

private Q_SLOTS:
    void onAutoSaveTimeout();
    void onContentsChangedForAutoSave();
```

### Step 5: Implement Auto-Save Logic in Document

**File:** `editors/sc-ide/core/doc_manager.cpp`

Add implementation after constructor initialization (around line 220):

```cpp
void Document::setupAutoSave() {
    mAutoSaveTimer.setSingleShot(true);
    connect(&mAutoSaveTimer, &QTimer::timeout, this, &Document::onAutoSaveTimeout);
}

void Document::onContentsChangedForAutoSave() {
    // Skip if no file path (untitled document)
    if (mFilePath.isEmpty())
        return;

    // Skip if auto-save is disabled
    Settings::Manager* settings = Main::settings();
    if (!settings->value("IDE/editor/autoSave").toBool())
        return;

    // Reset (debounce) the timer with current delay setting
    int delay = settings->value("IDE/editor/autoSaveDelay").toInt();
    mAutoSaveTimer.start(delay);
}

void Document::onAutoSaveTimeout() {
    // Double-check we still have a file path and auto-save is still enabled
    if (mFilePath.isEmpty())
        return;

    if (!Main::settings()->value("IDE/editor/autoSave").toBool())
        return;

    // Only save if actually modified
    if (!mDoc->isModified())
        return;

    // Request save through DocumentManager
    Main::documentManager()->save(this);
}
```

In `Document` constructor (around line 210), add:

```cpp
setupAutoSave();
```

### Step 6: Connect Auto-Save Signal

**File:** `editors/sc-ide/core/doc_manager.cpp`

In `DocumentManager::create()` (around line 261), add connection:

```cpp
connect(doc->textDocument(), &QTextDocument::contentsChanged,
        doc, &Document::onContentsChangedForAutoSave);
```

Also in `DocumentManager::restore()` (around line 608), add the same connection for restored documents:

```cpp
connect(doc->textDocument(), &QTextDocument::contentsChanged,
        doc, &Document::onContentsChangedForAutoSave);
```

### Testing Strategy

1. **Build and run:**
   ```bash
   cd build
   /Applications/CMake.app/Contents/bin/cmake --build . -j$(sysctl -n hw.ncpu) && \
   /Applications/CMake.app/Contents/bin/cmake --build . --target install
   open Install/SuperCollider/SuperCollider.app
   ```

2. **Test cases:**
   - Open Settings > Editor, verify Auto-Save group appears with checkbox and delay spinner
   - Enable auto-save with 2000ms delay
   - Open an existing .scd file
   - Make a change, wait 2 seconds - verify file is saved (modified indicator disappears)
   - Make rapid changes - verify debouncing works (only saves after you stop typing)
   - Create a new untitled document - verify it does NOT auto-save
   - Disable auto-save in settings - verify changes no longer auto-save
   - Test with various delay values (100ms, 5000ms)
   - Verify auto-backup still works independently

3. **Edge cases:**
   - File becomes read-only externally - verify graceful error handling
   - File is deleted externally - verify no crash
   - Settings changed while timer is pending - verify new delay takes effect

### Files Modified Summary

| File | Change |
|------|--------|
| `editors/sc-ide/core/settings/manager.cpp` | Add `autoSave` and `autoSaveDelay` defaults |
| `editors/sc-ide/forms/settings_editor.ui` | Add Auto-Save group box with checkbox and spin box |
| `editors/sc-ide/widgets/settings/editor_page.cpp` | Add load/store for auto-save settings |
| `editors/sc-ide/core/doc_manager.hpp` | Add `mAutoSaveTimer`, `setupAutoSave()`, slots |
| `editors/sc-ide/core/doc_manager.cpp` | Implement auto-save logic and connect signals |
