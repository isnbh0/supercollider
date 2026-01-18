# M4.7: Async Mutation + Code Execution Test

Verifies that a background process can mutate document text AND execute the modified code block without stealing cursor focus or scrolling the view.

## Prerequisites

- M4.6 passing (stealth edits via `doc.string_` work)
- SC IDE open

## Test File

`test-workspace.scd` - Single file containing mutation targets, utilities, and test blocks.

## Running the Test

1. Open `test-workspace.scd` in SC IDE
2. Run the **SETUP block** first (loads utilities and controller definitions)
3. Place cursor in the **TEST BLOCK** section (bottom of file)
4. Run the test block
5. Observe results

## What to Check

### Cursor Check
Does the cursor stay in the test block throughout mutations?
- **YES** = PASS
- **NO** (cursor jumps to mutation site) = FAIL

### View Check
Does the view scroll to show the mutation targets at the top?
- **NO** (view stays put) = PASS
- **YES** (view scrolls) = FAIL

### Execution Check
Do you see `[EXEC]` messages in the post window?
```
[EXEC] ~alpha executed with '...' (count: 1)
[EXEC] ~beta executed with '.....' (count: 1)
```
- **YES** = Code executed successfully
- **NO** = Code execution failed

### Counter Check
After test completes, verify execution counts:
```
~alphaCount = 1 (expected: 1)
~betaCount = 1 (expected: 1)
~gammaCount = 1 (expected: 1)
~deltaCount = 1 (expected: 1)
```

## Test Variants

| Test | Description | Duration |
|------|-------------|----------|
| Main | 4 mutations at 1s intervals | ~5s |
| 4.7a | Single mutation after 2s | ~3s |
| 4.7b | Rapid stress (10 mutations, 0.3s apart) | ~4s |
| 4.7c | Side effect verification | ~4s |

## Key Implementation

```supercollider
~m47MutateAndExecute = { |doc, controllerName, newValue|
    // Step 1: Stealth edit (no cursor/scroll steal)
    ~m47ReplaceNoCursorMove.(doc, controllerName, newValue);

    // Step 2: Execute the code
    var code = "~" ++ controllerName ++ ".(\"" ++ newValue ++ "\")";
    code.interpret;
};
```

## Success Criteria

- [ ] Cursor stays in test block throughout
- [ ] View doesn't scroll to mutation site
- [ ] Code executes (counters increment, `[EXEC]` messages appear)
- [ ] Works for rapid successive mutations (stress test)
