# Self-Editing Project Migration Plan

## Overview

Migrate 26 commits from `sc_workshop/projects/glitch-workshop/` to `supercollider/workspace/useless-machine/`.

**Source repo:** `/Users/jhchoi/local/src/sc_workshop`
**Target repo:** `/Users/jhchoi/local/src/supercollider`
**Target dir:** `workspace/useless-machine/`

## Current State

- [x] Prerequisites committed (2ec2eef84): glitch-loader.scd, samplepack/, study-3.scd

## Strategy

For each commit:
1. Show the original commit diff
2. Manually apply changes to target files
3. Commit with original message + timestamp preservation

### Timestamp Preservation

Use `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE` to preserve original timestamps:
```bash
GIT_AUTHOR_DATE="<original-date>" GIT_COMMITTER_DATE="<original-date>" git commit -m "message"
```

---

## Phase 0: Foundation (2 commits)

### Commit 1: d59d82c - Add soundtest synth with glitch effects
- **Date:** Sun Jan 11 13:49:39 2026 +0900
- **Files:** soundtest.scd (new), study-3.scd (minor edit)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show d59d82c`
- [ ] Create soundtest.scd from: `git -C /Users/jhchoi/local/src/sc_workshop show d59d82c:projects/glitch-workshop/soundtest.scd`
- [ ] Apply study-3.scd changes (adds 2 blank lines at end)
- [ ] Commit with preserved timestamp

### Commit 2: 590c140 - Implement reverb routing in soundtest
- **Date:** (check with `git log`)
- **Files:** soundtest.scd
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 590c140`
- [ ] Apply changes to soundtest.scd
- [ ] Commit with preserved timestamp

---

## Phase 1: Conception (2 commits)

### Commit 3: bf0c64a - Add wildcard.scd
- **Files:** wildcard.scd (new)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show bf0c64a`
- [ ] Create wildcard.scd
- [ ] Commit with preserved timestamp

### Commit 4: 1daad18 - Integrate wildcard synthesis into soundtest
- **Files:** WILDCARD_PLAN.md (new), soundtest.scd, soundtest_backup.scd (new), wildcard.scd, samplepack/*.wav (mode changes)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 1daad18`
- [ ] Create WILDCARD_PLAN.md
- [ ] Create soundtest_backup.scd
- [ ] Apply soundtest.scd changes
- [ ] Apply wildcard.scd changes
- [ ] Commit with preserved timestamp

---

## Phase 2: Bug Fixes (9 commits)

### Commit 5: ff28f29 - Fix SuperCollider bugs in wildcard.scd
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show ff28f29`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 6: a1550d9 - Fix additional SuperCollider bugs found in second review
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show a1550d9`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 7: dfb75d0 - Add execution order guards to prevent race condition crashes
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show dfb75d0`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 8: 61a3e17 - Fix remaining state and safety issues
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 61a3e17`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 9: 7c7b2e6 - Merge origin/log/260110 with bug fixes
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 7c7b2e6`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 10: eff33c3 - Fix SuperCollider safety and correctness issues
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show eff33c3`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 11: 43e01b0 - Fix performance loop timing and safety issues
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 43e01b0`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 12: 17b34b6 - Make coda aggressively crash the server
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 17b34b6`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 13: f07a113 - Add warning comments: server crash is intentional
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show f07a113`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

---

## Phase 3: Pivot (1 commit)

### Commit 14: 0a1ce63 - Remove wildcard.scd and cleanup unused code
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 0a1ce63`
- [ ] Apply changes (may delete wildcard.scd)
- [ ] Commit with preserved timestamp

---

## Phase 4: Specification (1 commit)

### Commit 15: 7db74cc - Add wildcard visual specification and initial tests
- **Files:** 260111-185743-wildcard-visual-spec.md (new), wildcard-visual-impl-log.md (new), wildcard-visual-m0-tests.scd (new), wildcard-visual-m05-diagnostic.scd (new)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 7db74cc`
- [ ] Create all new files
- [ ] Commit with preserved timestamp

---

## Phase 5: Implementation (3 commits)

### Commit 16: 5d95233 - Implement wildcard visual M09 converter
- **Files:** wildcard-visual-m09-converter.scd (new), wildcard-visual-m09-module.scd (new), m09-test-vectors.py (new)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 5d95233`
- [ ] Create new files
- [ ] Commit with preserved timestamp

### Commit 17: e7baeed - Add wildcard visual M1 inspection synth
- **Files:** TIL.md (new), wildcard-visual-m1-inspection.scd (new), wildcard-visual-test-target.scd (new), spec updates
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show e7baeed`
- [ ] Create/update files
- [ ] Commit with preserved timestamp

### Commit 18: 2576d09 - Refine wildcard visual spec and move tests
- **Files:** Moves files to tests/ subdirectories
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 2576d09`
- [ ] Apply file moves and changes
- [ ] Commit with preserved timestamp

---

## Phase 6: Test Infrastructure (2 commits)

### Commit 19: 5363df0 - Add M15 test utilities
- **Files:** tests/m15/*.scd (new)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 5363df0`
- [ ] Create test files
- [ ] Commit with preserved timestamp

### Commit 20: b0305c8 - Add M2 test framework
- **Files:** tests/m2/*.scd (new)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show b0305c8`
- [ ] Create test files
- [ ] Commit with preserved timestamp

---

## Phase 7: Bug Discovery (6 commits)

### Commit 21: 85912d7 - Add m2 surrogate pairs bug report
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 85912d7`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 22: ad8c43c - Add m09 selectRange length test
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show ad8c43c`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 23: 6f1a545 - Add M2 selectRange experiment
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 6f1a545`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 24: 7eaf225 - Add selectRange test to M2 test suite
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 7eaf225`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

### Commit 25: 2ce890c - Document SC IDE surrogate pair bug
- **Files:** 260113-001815-scide-surrogate-pair-bug-report.md (new)
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show 2ce890c`
- [ ] Create bug report file
- [ ] Commit with preserved timestamp

### Commit 26: bceed3c - Finalize M2 test assertions and syntax
- [ ] View diff: `git -C /Users/jhchoi/local/src/sc_workshop show bceed3c`
- [ ] Apply changes
- [ ] Commit with preserved timestamp

---

## Helper Commands

### View a commit's changes:
```bash
git -C /Users/jhchoi/local/src/sc_workshop show <hash>
```

### Get file content at a commit:
```bash
git -C /Users/jhchoi/local/src/sc_workshop show <hash>:projects/glitch-workshop/<file>
```

### Get commit date:
```bash
git -C /Users/jhchoi/local/src/sc_workshop log -1 --format="%ai" <hash>
```

### Commit with preserved timestamp:
```bash
DATE=$(git -C /Users/jhchoi/local/src/sc_workshop log -1 --format="%ai" <hash>)
cd /Users/jhchoi/local/src/supercollider
git add workspace/useless-machine/<files>
GIT_AUTHOR_DATE="$DATE" GIT_COMMITTER_DATE="$DATE" git commit -m "<message>"
```

---

## Progress Tracker

| # | Hash | Message | Status |
|---|------|---------|--------|
| 0 | prereq | Prerequisites | DONE |
| 1 | d59d82c | Add soundtest synth | DONE |
| 2 | 590c140 | Implement reverb routing | DONE |
| 3 | bf0c64a | Add wildcard.scd | DONE |
| 4 | 1daad18 | Integrate wildcard synthesis | DONE |
| 5 | ff28f29 | Fix SC bugs in wildcard | DONE |
| 6 | a1550d9 | Fix additional SC bugs | DONE |
| 7 | dfb75d0 | Add execution order guards | |
| 8 | 61a3e17 | Fix state and safety issues | |
| 9 | 7c7b2e6 | Merge with bug fixes | |
| 10 | eff33c3 | Fix safety and correctness | |
| 11 | 43e01b0 | Fix performance loop timing | |
| 12 | 17b34b6 | Make coda crash server | |
| 13 | f07a113 | Add warning comments | |
| 14 | 0a1ce63 | Remove wildcard.scd | |
| 15 | 7db74cc | Add visual spec + M0 tests | |
| 16 | 5d95233 | Implement M09 converter | |
| 17 | e7baeed | Add M1 inspection + TIL | |
| 18 | 2576d09 | Move tests to tests/ | |
| 19 | 5363df0 | Add M15 test utilities | |
| 20 | b0305c8 | Add M2 test framework | |
| 21 | 85912d7 | Add surrogate pairs bug report | |
| 22 | ad8c43c | Add selectRange length test | |
| 23 | 6f1a545 | Add selectRange experiment | |
| 24 | 7eaf225 | Add selectRange test to M2 | |
| 25 | 2ce890c | Document surrogate pair bug | |
| 26 | bceed3c | Finalize M2 assertions | |

---

## Session Resume Instructions

When resuming in a new Claude session:

1. Read this file: `/Users/jhchoi/local/src/supercollider/workspace/useless-machine/MIGRATION_PLAN.md`
2. Check current progress: `git -C /Users/jhchoi/local/src/supercollider log --oneline workspace/useless-machine/`
3. Find last completed commit in Progress Tracker
4. Continue from next uncompleted commit
5. Update Progress Tracker after each commit
