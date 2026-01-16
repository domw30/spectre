# spectre

An autonomous agent workflow that turns markdown specs into pull requests using Claude.

## Prerequisites

- [Claude Code CLI](https://claude.ai/code) (`claude` command)
- Git
- GitHub CLI (`gh`) - optional, for auto-creating PRs

## Setup (One-time per repo)

Copy these files into your target repository:

```
.agent/
├── CONTRACT.md          # Agent instructions
└── spec.template.md     # Spec template

tools/
└── agent_run.sh         # Execution script
```

Make the script executable:

```bash
chmod +x tools/agent_run.sh
```

Configure your repo's check commands at the top of `tools/agent_run.sh`:

```bash
LINT_CMD="npm run lint"
LINT_FIX_CMD="npm run lint:fix"
TYPECHECK_CMD="npm run typecheck"
TEST_CMD="npm test"
BUILD_CMD="npm run build"
```

Set any command to `""` to skip that check.

## Usage

### 1. Write a spec

Copy the template and fill it in:

```bash
cp .agent/spec.template.md .agent/spec.md
```

Or create specs in a dedicated folder:

```bash
cp .agent/spec.template.md specs/my-feature.md
```

### 2. Run the agent

```bash
./tools/agent_run.sh .agent/spec.md
# or
./tools/agent_run.sh specs/my-feature.md
```

The agent will:
1. Create a timestamped branch (`agent/YYYYMMDD-HHMMSS`)
2. Plan the implementation
3. Write the code
4. Run repo checks and fix failures
5. Commit and create a PR

### 3. Review and ship

Review the generated PR, fix any remaining issues, and merge.

## Optional: Discovery Phase

For complex tasks, run a discovery phase first to research the codebase:

```bash
claude "Read the codebase and create .agent/discovery.md with:
- Relevant files and patterns found
- Technical findings
- Recommended approach
- Assumptions and open questions

Task: [describe what you're trying to build]"
```

Then use the findings to write a more informed spec.

## Generated Files

During execution, the agent creates:

| File | Purpose |
|------|---------|
| `.agent/plan.md` | Implementation plan |
| `.agent/status.md` | Progress tracking |
| `.agent/notes_for_pr.md` | PR description |

## Customization

- **Check commands**: Edit the config section at the top of `tools/agent_run.sh`
- **Workflow phases**: Modify `.agent/CONTRACT.md` to change how the agent plans/implements
- **Repo conventions**: Add repo-specific patterns to `CONTRACT.md` for the agent to follow
