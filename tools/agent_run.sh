#!/usr/bin/env bash
#
# spectre: Spec → PR Workflow
#
# Usage: ./tools/agent_run.sh [path-to-spec]
#
# This script automates the process of implementing a feature spec:
# 1. Creates a timestamped git branch
# 2. Runs Claude to plan the implementation
# 3. Runs Claude to implement the feature
# 4. Runs repo checks (lint, typecheck, test, build)
# 5. Commits changes
# 6. Opens a PR (if gh CLI is available)
#

set -euo pipefail

# ============================================================================
# CONFIGURE: Update these commands for your repository
# ============================================================================
# Set to empty string "" to skip a check

LINT_CMD="npm run lint"
LINT_FIX_CMD="npm run lint:fix"
TYPECHECK_CMD="npm run typecheck"
TEST_CMD="npm test"
BUILD_CMD="npm run build"

# ============================================================================

# Configuration
SPEC_FILE="${1:-.agent/spec.md}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
AGENT_DIR="$REPO_ROOT/.agent"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BRANCH_NAME="agent/$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        exit 1
    fi

    if ! command -v claude &> /dev/null; then
        log_error "claude CLI is required but not installed"
        log_info "Install from: https://claude.ai/code"
        exit 1
    fi

    if [ ! -f "$SPEC_FILE" ]; then
        log_error "Spec file not found: $SPEC_FILE"
        log_info "Create a spec file or copy from .agent/spec.template.md"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create git branch
create_branch() {
    log_info "Creating branch: $BRANCH_NAME"

    # Ensure we're on a clean state
    if [ -n "$(git status --porcelain)" ]; then
        log_warn "Working directory has uncommitted changes"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Aborted by user"
            exit 1
        fi
    fi

    git checkout -b "$BRANCH_NAME"
    log_success "Created and switched to branch: $BRANCH_NAME"
}

# Build check commands string for Claude prompt
get_checks_prompt() {
    local checks=""
    [ -n "$LINT_CMD" ] && checks="$checks\n- Lint: $LINT_CMD"
    [ -n "$LINT_FIX_CMD" ] && checks="$checks (fix with: $LINT_FIX_CMD)"
    [ -n "$TYPECHECK_CMD" ] && checks="$checks\n- TypeCheck: $TYPECHECK_CMD"
    [ -n "$TEST_CMD" ] && checks="$checks\n- Test: $TEST_CMD"
    [ -n "$BUILD_CMD" ] && checks="$checks\n- Build: $BUILD_CMD"
    echo -e "$checks"
}

# Run Claude Plan phase
run_plan_phase() {
    log_info "Running Plan phase..."

    local plan_prompt="You are an autonomous repo agent. Read the CONTRACT at .agent/CONTRACT.md for your instructions.

Your task: Execute Phase 1 (Plan) for the spec at: $SPEC_FILE

1. Read the spec file carefully
2. Explore the codebase to understand existing patterns
3. Create a detailed implementation plan at .agent/plan.md
4. Initialize .agent/status.md with phase 'Planning Complete' and a task checklist

Do NOT implement anything yet. Only plan and document."

    claude --print "$plan_prompt" || {
        log_error "Plan phase failed"
        exit 1
    }

    if [ ! -f "$AGENT_DIR/plan.md" ]; then
        log_error "Plan phase did not create .agent/plan.md"
        exit 1
    fi

    log_success "Plan phase complete"
}

# Run Claude Implement phase
run_implement_phase() {
    log_info "Running Implement phase..."

    local checks_prompt
    checks_prompt=$(get_checks_prompt)

    local implement_prompt="You are an autonomous repo agent. Read the CONTRACT at .agent/CONTRACT.md for your instructions.

Your task: Execute Phase 2 (Implement) based on the plan at .agent/plan.md

1. Implement the plan step by step
2. Update .agent/status.md after each major step
3. Follow existing code patterns and conventions
4. When done, create .agent/notes_for_pr.md with PR description

After implementation, run these repo checks:$checks_prompt

If checks fail, fix the issues and re-run until they pass."

    claude --print "$implement_prompt" || {
        log_error "Implement phase failed"
        exit 1
    }

    log_success "Implement phase complete"
}

# Run a single check
run_single_check() {
    local name="$1"
    local cmd="$2"
    local fix_cmd="${3:-}"

    if [ -z "$cmd" ]; then
        log_info "Skipping $name check (not configured)"
        return 0
    fi

    log_info "Running $name check ($cmd)..."
    if eval "$cmd"; then
        log_success "$name check passed"
        return 0
    else
        if [ -n "$fix_cmd" ]; then
            log_warn "$name check failed, attempting auto-fix..."
            eval "$fix_cmd" || true
            if eval "$cmd"; then
                log_success "$name check passed after auto-fix"
                return 0
            fi
        fi
        log_error "$name check failed"
        return 1
    fi
}

# Run repo checks
run_checks() {
    log_info "Running repo checks..."
    local checks_passed=true

    run_single_check "Lint" "$LINT_CMD" "$LINT_FIX_CMD" || checks_passed=false
    run_single_check "TypeCheck" "$TYPECHECK_CMD" "" || checks_passed=false
    run_single_check "Test" "$TEST_CMD" "" || checks_passed=false
    run_single_check "Build" "$BUILD_CMD" "" || checks_passed=false

    if [ "$checks_passed" = false ]; then
        log_error "Some checks failed - manual intervention required"
        return 1
    fi

    log_success "All checks passed"
    return 0
}

# Commit changes
commit_changes() {
    log_info "Committing changes..."

    # Stage all changes
    git add -A

    # Get spec title for commit message
    local spec_title
    spec_title=$(head -1 "$SPEC_FILE" | sed 's/^#* *//')

    # Commit
    git commit -m "feat: $spec_title

Implemented via spectre workflow.

Co-Authored-By: Claude <noreply@anthropic.com>" || {
        log_warn "Nothing to commit or commit failed"
        return 1
    }

    log_success "Changes committed"
}

# Create PR
create_pr() {
    log_info "Creating pull request..."

    local notes_file="$AGENT_DIR/notes_for_pr.md"

    if ! command -v gh &> /dev/null; then
        log_warn "GitHub CLI (gh) not installed"
        echo ""
        echo "============================================"
        echo "Manual PR Creation Instructions:"
        echo "============================================"
        echo "1. Push your branch:"
        echo "   git push -u origin $BRANCH_NAME"
        echo ""
        echo "2. Create PR at:"
        echo "   https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/$BRANCH_NAME"
        echo ""
        if [ -f "$notes_file" ]; then
            echo "3. Use contents of .agent/notes_for_pr.md for PR description"
        fi
        echo "============================================"
        return 0
    fi

    # Push branch
    git push -u origin "$BRANCH_NAME" || {
        log_error "Failed to push branch"
        return 1
    }

    # Create PR
    if [ -f "$notes_file" ]; then
        gh pr create --fill --body-file "$notes_file" || {
            log_error "Failed to create PR"
            return 1
        }
    else
        gh pr create --fill || {
            log_error "Failed to create PR"
            return 1
        }
    fi

    log_success "Pull request created"
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║         spectre: Spec → PR Workflow         ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""

    log_info "Spec file: $SPEC_FILE"
    log_info "Branch: $BRANCH_NAME"
    echo ""

    # Change to repo root
    cd "$REPO_ROOT"

    # Execute workflow
    check_prerequisites
    create_branch
    run_plan_phase
    run_implement_phase

    # Run checks and fix if needed
    if ! run_checks; then
        log_warn "Checks failed - attempting Claude-assisted fix..."
        local checks_prompt
        checks_prompt=$(get_checks_prompt)
        claude --print "Fix the failing repo checks. Run these checks and fix any errors:$checks_prompt"
        run_checks || {
            log_error "Could not fix all check failures"
            log_info "Please fix manually and run: git add -A && git commit"
            exit 1
        }
    fi

    commit_changes
    create_pr

    echo ""
    log_success "Workflow complete!"
    echo ""
}

# Run main
main "$@"
