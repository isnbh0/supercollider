# Meta-Spec: Investigate WebEngine Crash on macOS 26+

**Date:** 2026-01-10 14:33:12
**Type:** Investigation (Meta-Spec)
**Issue:** QtWebEngine causes crashes on macOS 26+, disabling help browser functionality
**Priority:** Medium
**Status:** Completed
**Started:** 2026-01-10
**Completed:** 2026-01-10

## Investigation Results

### Root Cause

The "WebEngine crash" was actually a **framework bundling issue** with QtDBus, not a macOS 26-specific WebEngine problem.

When QtWebEngine is enabled and the app launches its `QtWebEngineProcess` helper subprocess, the helper's `@executable_path` differs from the main app's. The existing QtDBus bundling code (added in commit 696c63f1e) used `@executable_path/../Frameworks/...` paths, which work for the main app but fail for QtWebEngineProcess because:

- Main app: `@executable_path` = `SuperCollider.app/Contents/MacOS/`
- Helper app: `@executable_path` = `QtWebEngineProcess.app/Contents/MacOS/`

The helper looks for QtDBus at `QtWebEngineProcess.app/Contents/Frameworks/QtDBus.framework` which doesn't exist.

### Fix Applied

Changed the `install_name_tool` commands in `editors/sc-ide/CMakeLists.txt` to use `@rpath` instead of `@executable_path`. This works because QtWebEngineProcess has `@loader_path/../../../../../../../` in its rpath, which correctly resolves to the main app's Frameworks directory.

**File changed:** `editors/sc-ide/CMakeLists.txt` (lines 532-536)

**Before:**
```cmake
execute_process(COMMAND install_name_tool -id @executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus ...)
execute_process(COMMAND install_name_tool -change @rpath/QtCore.framework/Versions/A/QtCore @executable_path/../Frameworks/QtCore.framework/Versions/A/QtCore ...)
execute_process(COMMAND install_name_tool -change @rpath/QtDBus.framework/Versions/A/QtDBus @executable_path/../Frameworks/QtDBus.framework/Versions/A/QtDBus ...)
```

**After:**
```cmake
execute_process(COMMAND install_name_tool -id @rpath/QtDBus.framework/Versions/A/QtDBus ...)
execute_process(COMMAND install_name_tool -change @rpath/QtCore.framework/Versions/A/QtCore @rpath/QtCore.framework/Versions/A/QtCore ...)
execute_process(COMMAND install_name_tool -change @rpath/QtDBus.framework/Versions/A/QtDBus @rpath/QtDBus.framework/Versions/A/QtDBus ...)
```

### Verification

After applying the fix:
1. Built with `-DSC_USE_QTWEBENGINE=ON`
2. App launches successfully
3. QtWebEngineProcess helper spawns correctly
4. No dyld library loading errors

---

## Problem Statement

- **Current state:** Building with `-DSC_USE_QTWEBENGINE=ON` reportedly causes crashes on macOS 26+
- **Workaround:** Building with `-DSC_USE_QTWEBENGINE=OFF` avoids crashes but disables the help browser
- **Goal:** Determine root cause and produce an implementation spec that enables WebEngine reliably

## Output Artifact

This meta-spec produces: **An implementation spec** (`YYMMDD-HHMMSS-fix-webengine-macos26.md`) containing:
- Root cause analysis with evidence
- Specific code/configuration changes to fix the issue
- Testing verification steps

If investigation concludes the issue is unfixable (upstream Qt bug, etc.), produce a **findings report** documenting why and any workarounds.

---

## Investigation Methodology

### Phase 1: Reproduce and Characterize

**Objective:** Confirm the crash exists and gather diagnostic information.

1. **Build with WebEngine enabled:**
   ```bash
   cd build
   /Applications/CMake.app/Contents/bin/cmake -DSC_USE_QTWEBENGINE=ON ..
   /Applications/CMake.app/Contents/bin/cmake --build . -j$(sysctl -n hw.ncpu)
   /Applications/CMake.app/Contents/bin/cmake --build . --target install
   ```

2. **Launch and trigger the crash:**
   - Open the app
   - Attempt to view help documentation
   - Note: Does it crash on launch? On first help access? On specific content?

3. **Capture crash diagnostics:**
   - Check Console.app for crash reports
   - Run from terminal to capture stderr: `./build/Install/SuperCollider/SuperCollider.app/Contents/MacOS/SuperCollider`
   - Look for stack traces, assertion failures, or error messages

4. **Document findings:**
   - When does crash occur? (launch, help open, specific action)
   - Crash signature (signal, faulting module, stack trace)
   - Any error messages before crash

### Phase 2: Form Hypotheses

Based on Phase 1 findings, evaluate these potential causes:

| Hypothesis | How to Test |
|------------|-------------|
| **H1: Qt version incompatibility** | Check Qt version (`brew info qt@6`), compare with Qt release notes for macOS 26 support |
| **H2: WebEngine sandbox/entitlement issue** | Check if crash is sandbox-related, try with different entitlements or codesigning |
| **H3: GPU/rendering pipeline issue** | Check if crash mentions GPU, Metal, or rendering; try `QT_QUICK_BACKEND=software` |
| **H4: Missing framework/library** | Check if crash is due to missing dependency; verify framework bundling |
| **H5: Initialization order issue** | Check if crash is during WebEngine init; review HelpBrowser construction |
| **H6: macOS API deprecation** | Check if crash involves deprecated macOS APIs that Qt still uses |

### Phase 3: Isolate and Test

For each plausible hypothesis from Phase 2:

1. **Design minimal test:**
   - Can you reproduce with a minimal Qt WebEngine app?
   - Does the issue occur with Qt's own WebEngine examples?

2. **Test potential fixes:**
   - If H3 (GPU): Try environment variables to force software rendering
   - If H4 (bundling): Check `otool -L` on WebEngine frameworks
   - If H5 (init): Try lazy initialization of HelpBrowser

3. **Document each test:**
   ```
   Test: [description]
   Hypothesis: H#
   Method: [what you did]
   Result: [crash/no crash/partial]
   Conclusion: [supports/refutes hypothesis]
   ```

### Phase 4: Develop Fix

Once root cause is identified:

1. **Implement minimal fix** - change only what's necessary
2. **Verify fix** - confirm help browser works without crash
3. **Regression test** - ensure fix doesn't break other functionality
4. **Document the fix** - explain why it works

### Phase 5: Write Implementation Spec

Create `workspace/specs/YYMMDD-HHMMSS-fix-webengine-macos26.md` containing:

- Root cause with evidence from investigation
- Specific file changes with code examples
- Build/configuration changes if needed
- Testing verification steps
- Any caveats or known limitations

---

## Investigation Log Template

Use this format to document progress:

```markdown
## Investigation Log

### [Date/Time] - Phase X: [Activity]

**Action:** [What you did]

**Observation:** [What happened]

**Analysis:** [What it means]

**Next step:** [What to try next]
```

---

## Success Criteria

Investigation is complete when ONE of:

1. **Fix identified:** Implementation spec written with verified fix
2. **Upstream issue confirmed:** Bug reported to Qt/documented as external dependency
3. **Workaround documented:** Alternative approach that preserves help functionality

---

## Notes for Implementer

- Keep investigation log as you work - it's valuable even if fix isn't found
- Don't spend more than ~2 hours before reassessing approach
- Check Qt bug tracker and forums - someone may have already solved this
- Consider whether a different help rendering approach (non-WebEngine) is viable
- The crash may be intermittent - test multiple times before concluding "fixed"
