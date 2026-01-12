---
description: Audit and update all documentation to match current code state
---

You are performing a documentation garbage collection - systematically auditing all documentation files to ensure they accurately reflect the current state of the codebase.

## Philosophy

Documentation should be **downstream from code**. When code changes, documentation often lags behind. This command treats documentation as a derivative artifact that must be synchronized with the source of truth: the code itself.

## Step 0: Create Rollback Point

Before making any changes, record the current state:

```bash
git stash push -m "garbage-collect-backup-$(date +%y%m%d-%H%M%S)" --include-untracked
git stash pop
git rev-parse HEAD
```

Save this commit hash. If anything goes wrong, you can restore with `git checkout <hash> -- .`

## Step 1: Discover Documentation Files

Find all documentation files in the project:

```bash
find . -type f \( -name "*.md" -o -name "CLAUDE.md" \) \
  -not -path "./.git/*" \
  -not -path "./node_modules/*" \
  -not -path "./.venv/*" \
  -not -path "./workspace/specs/archive/*" \
  2>/dev/null | sort
```

## Step 2: Identify Key Code Artifacts to Cross-Reference

Before auditing docs, gather the current state of key artifacts:

1. **Service names and URLs** - Check deployment configs, GitHub Actions workflows
2. **API endpoints and response formats** - Check route definitions and models
3. **Configuration options** - Check config files, environment variables
4. **Available commands** - Check Makefile, package.json scripts
5. **Directory structure** - Check actual file layout vs documented structure
6. **Feature flags and modes** - Check domain models and enums

## Step 3: Systematic Audit

For each documentation file, check for:

### Staleness Indicators
- **Deprecated names**: Old service names, URLs, or identifiers
- **Missing features**: Recently added functionality not documented
- **Outdated examples**: Code samples that no longer work
- **Wrong response formats**: API documentation that doesn't match actual responses
- **Missing commands**: New make targets or scripts not listed
- **Stale file listings**: README files listing files that don't exist or missing new ones

### Common Drift Patterns
- Infrastructure migrations (service renames, URL changes)
- New API parameters or response fields
- New personality modes, variants, or feature flags
- Configuration changes (environment variables, settings)
- Dependency or tooling changes

## Step 4: Create Update Plan

Use TodoWrite to create a checklist of all files needing updates:

```
Example:
- [ ] README.md - Update URLs to dev-* prefix, add new mode
- [ ] LOCAL_SETUP.md - Fix response format, add new command
- [ ] CLAUDE.md - Update logging commands
- [ ] agents/README.md - Rewrite with current file list
```

## Step 5: Implement Updates

For each file:

1. Read the current documentation
2. Compare against actual code state
3. Make targeted edits to fix discrepancies
4. Follow the documentation principle: **write as current truth, not migration narrative**
   - Remove phrases like "has been migrated", "was renamed to", "used to be"
   - Write as if it always existed this way

## Step 6: Commit Changes

After all updates:

1. Stage all modified documentation files
2. Run pre-commit hooks
3. Commit with message format:
   ```
   docs: garbage collect stale documentation

   Synchronized documentation with current code state:
   - [List key changes]

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

## Audit Checklist

When examining each doc, verify:

- [ ] All URLs point to current services
- [ ] All service/resource names are current
- [ ] API examples use correct request/response formats
- [ ] All available modes/variants/options are listed
- [ ] All make commands and scripts are documented
- [ ] File/directory listings match reality
- [ ] Environment variables are current
- [ ] No migration/transition language remains

## Files to Always Check

These files commonly drift from code:

1. `README.md` - Main project documentation
2. `CLAUDE.md` - Claude Code instructions
3. `**/README.md` - Subdirectory documentation
4. `*.md` in `.local/` - Deployment and setup guides
5. `AGENTS.md` files - Agent-specific instructions

## Guardrails

- **Read before write**: Always read a file before editing it
- **Surgical edits**: Use Edit tool for targeted changes, not Write for full rewrites
- **Preserve structure**: Don't reorganize or add new sections - only synchronize content
- **Flag uncertainty**: If unsure whether something is stale or intentional, ask the user
- **Respect .gitignore**: Note but don't commit changes to ignored files
- **One commit**: Batch all doc updates into a single atomic commit

## Rollback

If something goes wrong mid-process:

```bash
# Discard all uncommitted changes
git checkout -- .

# Or restore to the saved commit hash
git checkout <saved-hash> -- .
```

If already committed but need to undo:

```bash
git revert HEAD --no-edit
```
