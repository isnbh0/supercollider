# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A SuperCollider live coding performance system featuring an "autonomous chaos engine" called WILDCARD. The core concept: a background routine randomly mutates audio synthesis parameters to create dramatic, unexpected musical changes as a theatrical element.

## Quick Start

```supercollider
// In SC IDE, open soundtest.scd then run in order:
~boot.();      // Boot server, load samples
~prep.();      // Set up generators
~start.();     // Start playback

// Load and run chaos engine:
(Document.current.dir ++ "/wildcard.scd").load;
~wildcardStart.();           // Begin chaos (auto-saves state)
~wildcardSetLevel.(3);       // 1=subtle, 5=total chaos
~wildcardCoda.();            // 30-sec final collapse
~wildcardStop.();            // Stop chaos
~wildcardRecover.();         // Emergency stop + restore state
```

## Running Tests

Tests are in `tests/` with subdirectories for each module (m0, m05, m09, m1, m15, m2).

```supercollider
// Open the test target file, then:
(Document.current.dir ++ "/test-runner.scd").load
```

Test areas:
- **M09**: UTF-8 byte to UTF-16 code unit conversion
- **M2**: Text replacement with unicode edge cases
- **M1**: Visual inspection synth for audio analysis

## Architecture

**soundtest.scd** - Core audio engine
- 4 generators with probability/duration/amplitude specs
- Sample-based playback with jitter/speed control
- State management via `~stateSnapshot.()`/`~stateRestore.()`

**wildcard.scd** - Chaos engine that mutates soundtest parameters
- 5 mutation types: STUTTER, JITTER, SAMPLE, IMPACT, GLITCH
- 5 chaos levels (escalating control)
- Coda system: exponential escalation to intentional system crash
- Theatrical output: ASCII art banners, Zalgo glitch text, mutation logging

**tests/m09/** - UTF-8/UTF-16 converter module for Document manipulation

## SuperCollider Quirks (see TIL.md for details)

| Issue | Solution |
|-------|----------|
| `Document.open` is synchronous | Don't pass callback - `var doc = Document.open(path);` |
| `.load` requires single expression | Use bare statements in modules, `()` blocks in test files |
| String uses UTF-8 bytes, Document uses UTF-16 | Convert with `~byteToUtf16.()` before `selectRange` |
| `var` must be at block top | Declare all vars before any statements |
| `.wait` needs Routine context | Use `.fork(AppClock)`, not `.defer` |

## Known Issues

**Surrogate pairs in Document selection** (FIXED): Required SC IDE patch in commit `86238d725`. See `tests/m2/BUG-REPORT-surrogate-pairs.md` for details.

## Code Patterns

- Environment variables (`~name`) for shared state
- Comments with `@wildcard` marker indicate mutation targets
- Snapshot/restore pattern for state preservation
