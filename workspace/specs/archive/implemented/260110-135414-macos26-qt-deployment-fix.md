# macOS 26 Qt Deployment - QtDBus Bundling Fix

**Date:** 2026-01-10 13:54:14
**Issue:** SuperCollider IDE fails to launch on macOS 26 due to missing QtDBus framework in app bundle
**Priority:** High
**Status:** Completed
**Implementation:**
- Commit: 696c63f1e - fix(macos): bundle QtDBus.framework for Homebrew Qt on macOS 26+
**Completed:** 2026-01-10

## Problem Statement

- **Current behavior**: After building SuperCollider with Homebrew Qt 6.9.3 on macOS 26, the IDE crashes immediately on launch with `Library not loaded: @rpath/QtDBus.framework/Versions/A/QtDBus`
- **Expected behavior**: The app bundle should include all required Qt frameworks and launch successfully
- **Impact**: Developers on macOS 26 cannot run locally-built SuperCollider without manual workarounds

### Error Observed

```
dyld[...]: Library not loaded: @rpath/QtDBus.framework/Versions/A/QtDBus
  Referenced from: <...>/SuperCollider.app/Contents/Frameworks/QtGui.framework/Versions/A/QtGui
  Reason: tried: '/opt/homebrew/lib/QtDBus.framework/Versions/A/QtDBus' (no such file)
```

After manual QtDBus copy, a secondary issue occurs: code signature invalid (fixed by re-signing).

## Root Cause Analysis

### Investigation Methodology

1. Built SuperCollider on macOS 26.1 (M1 Pro) with Homebrew Qt 6.9.3
2. Attempted launch - crashed with QtDBus missing
3. Verified QtDBus is a transitive dependency of QtGui
4. Tested aqtinstall Qt 6.7.3 and 6.8.2 as alternatives - both failed due to AGL framework deprecation

### Technical Root Cause

**Primary Issue - macdeployqt Limitation:**
- `macdeployqt` (Qt's deployment tool) does not bundle QtDBus.framework on macOS
- QtDBus is typically a Linux/D-Bus component but Qt6 on macOS includes it as a transitive dependency of QtGui
- SuperCollider's `CMakeLists.txt` at `editors/sc-ide/CMakeLists.txt:467-580` runs macdeployqt but has no mechanism to handle this missing framework
- GitHub Issue #6481 documents related @rpath verification failures with Homebrew Qt

**Secondary Issue - Code Signing:**
- Any modification to binaries (via install_name_tool) invalidates Apple code signatures
- ARM64 binaries require valid signatures to run
- The existing `SC_CODESIGN_AFTER_DEPLOY` mechanism (PR #5650) signs all frameworks in the Frameworks directory, so manually-added frameworks will be signed IF added before the signing step runs

**Alternative Qt Sources Tested:**

| Qt Source | Version | Result |
|-----------|---------|--------|
| Homebrew | 6.9.3 | Builds successfully, QtDBus not bundled |
| aqtinstall | 6.8.2 | Fails: `ld: framework not found AGL` |
| aqtinstall | 6.7.3 | Fails: `ld: framework not found AGL` |

The AGL (Apple Graphics Library) framework was deprecated and removed in macOS 26 SDK. Qt binaries from aqtinstall were built against older SDKs that reference AGL.

### Relevant Code

Current deployment logic in `editors/sc-ide/CMakeLists.txt`:

- **Lines 470-489**: macdeployqt command construction
- **Lines 491-510**: Homebrew Qt fix for QtQuickWidgets (only when `SC_USE_QTWEBENGINE=ON` and Qt < 6.9.3)
- **Lines 518-542**: Code signing after deploy (`SC_CODESIGN_AFTER_DEPLOY`)

The gap: No handling for QtDBus.framework, which QtGui requires at runtime regardless of WebEngine setting.

## Technical Approach

Given the preference for minimizing changes to build scripts, three options are presented in order of preference.

**Caveat:** Minimal-touch is a priority but not a hard constraint. If the simpler options prove insufficient for this specific environment (macOS 26.1 + Homebrew Qt 6.9.3 + ARM64), more extensive modifications are acceptable. The goal is to avoid unnecessary complexity, not to avoid necessary fixes.

### Option A: Minimal CMake Addition (Recommended)

Follow the existing pattern used for QtQuickWidgets (`CMakeLists.txt:497-509`) to add QtDBus bundling. This adds ~25 lines following an established pattern.

### Option B: Post-Build Script

Create a standalone fixup script that developers run after building. Not integrated into CMake.

### Option C: Document Manual Workaround

Add documentation for manual workaround without any code changes.

**Recommended: Option A** - It follows an existing pattern, runs automatically, and is localized to one file.

## Implementation Details

### Option A: Minimal CMake Addition

**Files to modify:**
- `editors/sc-ide/CMakeLists.txt` - Add QtDBus deployment block (~25 lines)

**Challenge:** The existing Homebrew detection (lines 491-510) is inside a block requiring `SC_USE_QTWEBENGINE=ON` and `Qt6 < 6.9.3`. QtDBus fix must work:
- Without WebEngine (`-DSC_USE_QTWEBENGINE=OFF`)
- With Qt 6.9.3 (current Homebrew version)

**Location:** Insert after line 510 (after the `endif()` closing the QtQuickWidgets block).

**Code to add:**

```cmake
        # Fix deployment of QtDBus for Homebrew Qt (required by QtGui at runtime on macOS 26+)
        # This is separate from the QtQuickWidgets fix as it applies regardless of WebEngine
        if("${QT_VERSION_MAJOR}" GREATER_EQUAL 6)
            execute_process(COMMAND brew --prefix OUTPUT_VARIABLE BREW_PREFIX_CHECK OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
            if(BREW_PREFIX_CHECK)
                get_target_property(QtCore_location_check Qt${QT_VERSION_MAJOR}::Core LOCATION)
                cmake_path(IS_PREFIX BREW_PREFIX_CHECK ${QtCore_location_check} QT_IS_HOMEBREW_FOR_DBUS)
                if(QT_IS_HOMEBREW_FOR_DBUS)
                    execute_process(COMMAND brew --prefix qt6 OUTPUT_VARIABLE QT_BREW_PATH OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
                    if(NOT QT_BREW_PATH)
                        execute_process(COMMAND brew --prefix qt OUTPUT_VARIABLE QT_BREW_PATH OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
                    endif()
                    if(QT_BREW_PATH AND EXISTS "${QT_BREW_PATH}/lib/QtDBus.framework")
                        message(STATUS "Detected Homebrew Qt6: will bundle QtDBus.framework")
                        string(APPEND VERIFY_CMD "
                            message(STATUS \"Copying QtDBus.framework for Homebrew Qt\")
                            file(COPY ${QT_BREW_PATH}/lib/QtDBus.framework DESTINATION ${CONTENTS_DIR}/Frameworks)
                            execute_process(COMMAND install_name_tool -id @executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus ${CONTENTS_DIR}/Frameworks/QtDBus.framework/Versions/A/QtDBus)
                            execute_process(COMMAND install_name_tool -change @rpath/QtCore.framework/Versions/A/QtCore @executable_path/../Frameworks/QtCore.framework/Versions/A/QtCore ${CONTENTS_DIR}/Frameworks/QtDBus.framework/Versions/A/QtDBus)
                        ")
                    endif()
                endif()
            endif()
        endif()
```

**Note:** This creates independent Homebrew detection rather than reusing existing variables, since those are inside a conditional block. The existing `SC_CODESIGN_AFTER_DEPLOY` block at line 518 will sign the newly-added framework automatically.

### Option B: Post-Build Script

Create `tools/macos-fix-qtdbus.sh`:

```bash
#!/bin/bash
# Fix QtDBus bundling for Homebrew Qt builds on macOS 26+
# Run after: cmake --build . --target install

BUNDLE="$1"
if [ -z "$BUNDLE" ]; then
    BUNDLE="build/Install/SuperCollider/SuperCollider.app"
fi

QT_PREFIX=$(brew --prefix qt6 2>/dev/null || brew --prefix qt)
CONTENTS="$BUNDLE/Contents"

echo "Copying QtDBus.framework..."
cp -RL "$QT_PREFIX/lib/QtDBus.framework" "$CONTENTS/Frameworks/"

echo "Fixing install names..."
install_name_tool -id @executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus \
    "$CONTENTS/Frameworks/QtDBus.framework/Versions/A/QtDBus"
install_name_tool -change @rpath/QtCore.framework/Versions/A/QtCore \
    @executable_path/../Frameworks/QtCore.framework/Versions/A/QtCore \
    "$CONTENTS/Frameworks/QtDBus.framework/Versions/A/QtDBus"

echo "Re-signing..."
codesign --force --sign - "$CONTENTS/Frameworks/QtDBus.framework"
codesign --force --sign - "$BUNDLE"

echo "Done."
```

### Option C: Manual Workaround Documentation

Add to `README_MACOS.md`:

```markdown
### Homebrew Qt on macOS 26

If the IDE crashes on launch with "Library not loaded: QtDBus", run:

    QT=$(brew --prefix qt6)
    BUNDLE=build/Install/SuperCollider/SuperCollider.app
    cp -RL $QT/lib/QtDBus.framework $BUNDLE/Contents/Frameworks/
    install_name_tool -id @executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus \
        $BUNDLE/Contents/Frameworks/QtDBus.framework/Versions/A/QtDBus
    install_name_tool -change @rpath/QtCore.framework/Versions/A/QtCore \
        @executable_path/../Frameworks/QtCore.framework/Versions/A/QtCore \
        $BUNDLE/Contents/Frameworks/QtDBus.framework/Versions/A/QtDBus
    codesign --force --deep --sign - $BUNDLE
```

## Testing Strategy

Applies to all options:

```bash
# Clean build
rm -rf build && mkdir build && cd build

# Configure with Homebrew Qt (CMake will auto-detect, but explicit path shown for clarity)
/Applications/CMake.app/Contents/bin/cmake \
    -G Xcode \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DSC_USE_QTWEBENGINE=OFF \
    ..
# Note: Homebrew Qt is typically found automatically via PATH

# Build and install
/Applications/CMake.app/Contents/bin/cmake --build . --target install --config RelWithDebInfo

# Verify QtDBus is bundled
ls -la Install/SuperCollider/SuperCollider.app/Contents/Frameworks/QtDBus.framework

# Verify install names are correct
otool -L Install/SuperCollider/SuperCollider.app/Contents/Frameworks/QtDBus.framework/Versions/A/QtDBus

# Expected output should show @executable_path references, not @rpath

# Verify signature
codesign -vvv Install/SuperCollider/SuperCollider.app

# Launch
open Install/SuperCollider/SuperCollider.app
```

**Dependencies:**
- CMake 3.x (use `/Applications/CMake.app/Contents/bin/cmake`, not Homebrew's 4.x)
- Homebrew Qt 6.9.3: `brew install qt`
- Xcode 26+ with command line tools

**Verification Criteria:**
1. Build completes without errors
2. QtDBus.framework exists in app bundle Frameworks directory
3. `otool -L` shows `@executable_path` references, not `@rpath`
4. Code signature is valid
5. App launches without dyld errors
6. Interpreter starts successfully ("Welcome to SuperCollider" appears)

## Alternative Approaches Considered

### Alternative 1: Use aqtinstall Qt

**Why rejected:** Qt binaries from aqtinstall reference the deprecated AGL framework, causing linker failures on macOS 26. Would require waiting for Qt to update their macOS builds.

### Alternative 2: Build Qt from source

**Why rejected:** Time-consuming (2+ hours), complex configuration, not practical for most developers.

### Alternative 3: Patch QtGui to remove QtDBus dependency

**Why rejected:** Requires modifying Qt itself, not a SuperCollider-level fix.

### Alternative 4: Standalone script only (no CMake or documentation)

**Why not preferred:** While Option B provides a script, it's offered alongside documentation. A script-only approach without CMake integration or documentation would be incomplete.

## References

- GitHub Issue #6481: verify_app and Qt6 from Homebrew
- GitHub Issue #5603: Codesigning issues on M1
- GitHub PR #5650: Ad-hoc code signing integration
- GitHub PR #7190: Guard Homebrew deployment fix
- `.local/sc-qt-issues-research.md`: Comprehensive Qt issues research
- `.local/sc-build-synthesis-for-this-env.md`: Environment-specific build analysis
