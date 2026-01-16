# Agent Contract: Spec → PR Workflow

You are an **autonomous repo agent**. Your job is to take a specification and produce a working implementation with a pull request.

## Input

A markdown specification file (default: `.agent/spec.md`) containing:
- Feature description
- Requirements
- Acceptance criteria
- Any constraints or dependencies

## Execution Phases

### Phase 1: Plan

**Output:** `.agent/plan.md`

1. Read and analyze the spec file
2. Explore the codebase to understand:
   - Existing patterns and conventions
   - Related code that will be affected
   - Dependencies and interfaces
3. Create a detailed implementation plan:
   - List all files to create/modify
   - Describe changes for each file
   - Identify potential risks or blockers
   - Note any assumptions made
4. Initialize `.agent/status.md` with:
   - Current phase: "Planning Complete"
   - Checklist of implementation tasks

### Phase 2: Implement

**Output:** Code changes + `.agent/status.md` updates

1. Implement the plan step by step
2. Update `.agent/status.md` after each major step
3. Follow existing code patterns and conventions
4. Write clean, well-structured code
5. Add comments only where logic is non-obvious

### Phase 3: Validate

**Output:** Passing checks

1. Run all repo checks (lint, typecheck, test, build)
2. If any check fails:
   - Analyze the error
   - Fix the issue
   - Re-run checks
3. Repeat until all checks pass
4. Document any issues encountered in status.md

### Phase 4: Summarize

**Output:** `.agent/notes_for_pr.md`

Create PR notes containing:

```markdown
## Summary
[Brief description of what was implemented]

## Changes
- [List of files changed with brief descriptions]

## Setup Instructions
[Any steps needed to use the new feature]

## Testing
[How to verify the implementation works]

## TODOs / Future Work
- [Any remaining items or improvements]

## Notes
[Any important context for reviewers]
```

## Repo Checks

<!-- CONFIGURE: Update these commands for your repository -->

| Check | Command | Fix Command |
|-------|---------|-------------|
| **Lint** | `npm run lint` | `npm run lint:fix` |
| **Types** | `npm run typecheck` | *(manual)* |
| **Test** | `npm test` | *(manual)* |
| **Build** | `npm run build` | *(manual)* |

### Check Behavior

- **All checks must pass** before creating the PR
- If a check has an auto-fix command, run it and re-check
- If a check fails without auto-fix, analyze and fix manually

## Rules

1. **Never skip checks.** All validation must pass.
2. **Fix failures.** Don't just report them - fix them and re-run.
3. **Stay focused.** Only implement what's in the spec.
4. **Be explicit.** Document assumptions and decisions.
5. **Follow patterns.** Match existing code style and conventions.
6. **Update status.** Keep `.agent/status.md` current throughout.

## File Structure

```
.agent/
├── CONTRACT.md          # This file (agent instructions)
├── spec.md              # Current spec being implemented
├── spec.template.md     # Template for new specs
├── plan.md              # Implementation plan (generated)
├── status.md            # Current status (generated)
└── notes_for_pr.md      # PR description (generated)

tools/
└── agent_run.sh         # Script to execute the workflow
```

## Error Handling

If you encounter a blocker that cannot be resolved:

1. Document the issue in `.agent/status.md`
2. List what was attempted
3. Explain why it cannot proceed
4. Suggest next steps for a human to take
5. Exit gracefully (don't leave broken code)
