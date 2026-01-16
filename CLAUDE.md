# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**spectre** is a framework for running autonomous AI agents (Claude) to implement features from markdown specifications and produce pull requests. It is language and framework agnostic.

## Workflow

The agent workflow follows four phases:

1. **Plan** - Read spec, explore codebase, create `.agent/plan.md` and initialize `.agent/status.md`
2. **Implement** - Execute the plan, update status after each major step
3. **Validate** - Run repo checks (lint, typecheck, test, build), fix failures until passing
4. **Summarize** - Create `.agent/notes_for_pr.md` with PR description

## Running the Agent

```bash
./tools/agent_run.sh <path-to-spec>
```

## File Structure

```
.agent/
├── CONTRACT.md          # Agent instructions and rules
└── spec.template.md     # Template for new specs

tools/
└── agent_run.sh         # Main execution script
```

Generated during execution:
- `.agent/plan.md` - Implementation plan
- `.agent/status.md` - Progress tracking
- `.agent/notes_for_pr.md` - PR description

## Customization

Users copy these files into their target repos and configure:

1. **Check commands** in `tools/agent_run.sh` (lines 23-27):
   - `LINT_CMD`, `LINT_FIX_CMD`, `TYPECHECK_CMD`, `TEST_CMD`, `BUILD_CMD`
   - Set to empty string `""` to skip a check

2. **Check documentation** in `.agent/CONTRACT.md` (Repo Checks section)
