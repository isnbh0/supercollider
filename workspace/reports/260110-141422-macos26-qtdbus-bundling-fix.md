# macOS 26 QtDBus Framework Bundling Fix

**Date**: 2026-01-10 14:14:22
**Commit Hash**: 1013a08c6c77c3ed2fd74ad4c31526c987be5aee
**Analysis Scope**: Fix for SuperCollider IDE crash on macOS 26 with Homebrew Qt 6.9.3 due to missing QtDBus.framework

## Executive Summary

SuperCollider IDE failed to launch on macOS 26 when built with Homebrew Qt 6.9.3, crashing immediately with a dyld error about missing QtDBus.framework. The root cause was that `macdeployqt` does not bundle QtDBus.framework, despite QtGui having a runtime dependency on it.

The fix adds automatic QtDBus.framework bundling to the CMake build process for Homebrew Qt builds. The implementation required solving three sub-problems: preserving macOS framework symlink structure, fixing install names to use `@executable_path`, and updating QtGui's reference to QtDBus. The fix is transparent to users and works automatically during the build process.

## Key Findings

1. **QtGui depends on QtDBus at runtime on Homebrew Qt 6.9.3**

   Unlike aqtinstall Qt binaries, Homebrew's Qt build includes QtDBus as a dependency of QtGui:
   ```
   $ otool -L QtGui.framework/Versions/A/QtGui | grep DBus
   @rpath/QtDBus.framework/Versions/A/QtDBus
   ```

2. **macdeployqt does not bundle QtDBus.framework**

   The Qt deployment tool (`macdeployqt`) does not recognize QtDBus as a required dependency and omits it from the app bundle, resulting in:
   ```
   dyld[...]: Library not loaded: @rpath/QtDBus.framework/Versions/A/QtDBus
     Referenced from: .../SuperCollider.app/Contents/Frameworks/QtGui.framework/Versions/A/QtGui
   ```

3. **Framework structure must be preserved during copy**

   Initial attempts using `cp -RL` (dereference symlinks) broke the framework structure. macOS frameworks require specific symlink layouts:
   ```
   QtDBus.framework/
   ├── QtDBus -> Versions/Current/QtDBus    # symlink required
   ├── Resources -> Versions/Current/Resources
   └── Versions/
       ├── A/
       │   └── QtDBus                        # actual binary
       └── Current -> A
   ```
   Using `cp -RL` converted these symlinks to regular files, causing code signature validation failures.

4. **Install names required dual fixes**

   Two install_name_tool changes were necessary:
   - QtDBus's own ID: `@rpath/...` → `@executable_path/../Frameworks/...`
   - QtGui's reference to QtDBus: `@rpath/...` → `@executable_path/../Frameworks/...`

5. **Homebrew Qt frameworks are symlinks themselves**

   The path `/opt/homebrew/opt/qt/lib/QtDBus.framework` is a symlink to the Cellar location:
   ```
   /opt/homebrew/opt/qt/lib/QtDBus.framework -> ../../../../lib/QtDBus.framework
   ```
   This required resolving the real path before copying to avoid broken symlinks in the bundle.

## Root Cause Analysis

### Investigation Methodology

1. Built SuperCollider with Homebrew Qt 6.9.3 on macOS 26.1 (Apple M1 Pro)
2. Attempted launch - immediate crash with dyld error
3. Inspected QtGui dependencies with `otool -L`
4. Traced through `editors/sc-ide/CMakeLists.txt` deployment logic
5. Tested multiple copy strategies (`cp -RL`, `file(COPY)`, `ditto`)
6. Verified code signature requirements on ARM64

### Why macdeployqt Misses QtDBus

macdeployqt analyzes the dependency tree of the target application. QtDBus is not directly linked by any SuperCollider binary - it's a transitive dependency through QtGui. On most Qt installations (including aqtinstall), QtGui doesn't depend on QtDBus. However, Homebrew's Qt build configuration includes D-Bus support, creating this hidden dependency.

### Why Initial Fixes Failed

**Attempt 1: CMake file(COPY)**
```cmake
file(COPY ${QT_BREW_PATH}/lib/QtDBus.framework DESTINATION ${CONTENTS_DIR}/Frameworks)
```
Result: Copied the symlink itself, not the target → broken relative symlink in bundle

**Attempt 2: cp -RL (dereference symlinks)**
```cmake
execute_process(COMMAND cp -RL ${QTDBUS_REAL_PATH} ${CONTENTS_DIR}/Frameworks/)
```
Result: Framework structure lost → "bundle format is ambiguous" signature error → SIGKILL on launch

**Attempt 3: ditto (successful)**
```cmake
execute_process(COMMAND ditto ${QTDBUS_REAL_PATH} ${CONTENTS_DIR}/Frameworks/QtDBus.framework)
```
Result: Preserves framework structure including internal symlinks → valid signature → successful launch

### Code Signature Chain

On ARM64 macOS, all binaries must be signed. The issue cascaded as follows:

1. QtDBus.framework copied with broken structure
2. Codesign step signs the malformed framework
3. Signature appears valid (`codesign -vvv` passes)
4. At runtime, dyld validates signature pages
5. Mismatch between expected and actual binary layout
6. SIGKILL with "Code Signature Invalid" termination

## Implementation Details

### Files Modified

| File | Change |
|------|--------|
| `editors/sc-ide/CMakeLists.txt` | Added QtDBus bundling block (~31 lines) |

### Implementation Location

Inserted after line 510, following the existing QtQuickWidgets fix pattern:

```cmake
# Fix deployment of QtDBus for Homebrew Qt (required by QtGui at runtime on macOS 26+)
# This is separate from the QtQuickWidgets fix as it applies regardless of WebEngine
if("${QT_VERSION_MAJOR}" GREATER_EQUAL 6)
    execute_process(COMMAND brew --prefix OUTPUT_VARIABLE BREW_PREFIX_CHECK ...)
    if(BREW_PREFIX_CHECK)
        get_target_property(QtCore_location_check Qt${QT_VERSION_MAJOR}::Core LOCATION)
        cmake_path(IS_PREFIX BREW_PREFIX_CHECK ${QtCore_location_check} QT_IS_HOMEBREW_FOR_DBUS)
        if(QT_IS_HOMEBREW_FOR_DBUS)
            # ... detect Qt path, resolve symlinks, bundle QtDBus, fix install names
        endif()
    endif()
endif()
```

### Key Design Decisions

1. **Independent Homebrew detection**: Created new detection block rather than reusing existing variables, since the existing detection is inside a WebEngine-conditional block.

2. **Symlink resolution at configure time**: Used `get_filename_component(... REALPATH)` to resolve the Homebrew symlink before storing the path for install-time use.

3. **ditto for framework copy**: macOS's `ditto` tool correctly handles framework bundles, preserving the internal symlink structure that `cp -RL` destroys.

4. **Removal before copy**: Added `file(REMOVE_RECURSE ...)` to handle re-installs where a broken symlink might already exist.

5. **Relied on existing codesign step**: The `SC_CODESIGN_AFTER_DEPLOY` block already iterates over all frameworks and signs them, so no additional signing code was needed.

## Test Results

### Build Verification

```
$ cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DSC_USE_QTWEBENGINE=OFF ..
-- Detected Homebrew Qt6: will bundle QtDBus.framework from /opt/homebrew/Cellar/qtbase/6.9.3_1/lib/QtDBus.framework

$ cmake --build . --target install
-- Copying QtDBus.framework for Homebrew Qt
-- Fixing QtDBus reference in QtGui.framework
```

### Framework Structure Verification

```
$ ls -la .../Frameworks/QtDBus.framework/
lrwxr-xr-x  Headers -> Versions/Current/Headers
lrwxr-xr-x  QtDBus -> Versions/Current/QtDBus      # symlink preserved
lrwxr-xr-x  Resources -> Versions/Current/Resources
drwxr-xr-x  Versions/
```

### Install Name Verification

```
$ otool -L .../Frameworks/QtDBus.framework/Versions/A/QtDBus
@executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus  # ID fixed
@executable_path/../Frameworks/QtCore.framework/Versions/A/QtCore  # dependency fixed

$ otool -L .../Frameworks/QtGui.framework/Versions/A/QtGui | grep DBus
@executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus  # reference fixed
```

### Code Signature Verification

```
$ codesign -vvv .../Frameworks/QtDBus.framework
.../QtDBus.framework: valid on disk
.../QtDBus.framework: satisfies its Designated Requirement
```

### Launch Test

Application launches successfully without dyld errors. Interpreter starts and displays "Welcome to SuperCollider".

## Recommendations

1. **Consider upstream contribution**

   This fix addresses a real issue with Homebrew Qt on macOS 26. Consider submitting a PR to the SuperCollider main repository to benefit other developers.

2. **Monitor Qt dependency changes**

   Homebrew Qt's dependency graph may change in future versions. The current fix is specific to QtDBus; other transitive dependencies could appear.

3. **Document Homebrew Qt as supported**

   The research documents in `.local/` recommend aqtinstall Qt, but Homebrew Qt now works correctly. Consider updating guidance to reflect both as valid options.

4. **Add automated testing for deployment**

   The existing CI could include a Homebrew Qt build variant to catch similar deployment issues before release.

## Related Analysis

- Spec: `workspace/specs/archive/implemented/260110-135414-macos26-qt-deployment-fix.md`
- Research: `.local/sc-qt-issues-research.md`
- Environment synthesis: `.local/sc-build-synthesis-for-this-env.md`

## Commits

| Hash | Message |
|------|---------|
| `696c63f1e` | fix(macos): bundle QtDBus.framework for Homebrew Qt on macOS 26+ |
| `1013a08c6` | docs: archive macos26-qt-deployment-fix spec as completed |
