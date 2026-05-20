#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-worktree}"
BASE="${2:-origin/main}"
CONTEXT_LINES="${CLAUDE_REVIEW_CONTEXT_LINES:-40}"
TIMEOUT_SECONDS="${CLAUDE_REVIEW_TIMEOUT_SECONDS:-300}"
DIFF_CMD=()

PROMPT='You are an independent senior project reviewer. Review the diff from stdin only.
Focus only on high-confidence correctness, security, data-loss, broken links/references, API-contract, documentation-contract, and regression risks.
Do not comment on style unless it creates a real bug, ambiguity, or user-facing documentation problem.
Do not edit files.
If the diff is empty, say that there are no changes to review.
Output:
- Summary
- Critical findings
- Major findings
- Minor findings
- Suggested tests
Include file paths and line hints when possible.'

usage() {
  echo "Usage: $0 [worktree|staged|branch|head] [base-ref]" >&2
  echo "       $0 [base-ref]  # backward-compatible alias for: $0 branch [base-ref]" >&2
}

if [[ "$MODE" == "-h" || "$MODE" == "--help" || "$MODE" == "help" ]]; then
  usage
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found on PATH." >&2
  exit 127
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "claude-review must be run from inside a Git worktree." >&2
  exit 2
fi

if ! [[ "$CONTEXT_LINES" =~ ^[1-9][0-9]*$ ]]; then
  echo "CLAUDE_REVIEW_CONTEXT_LINES must be a positive integer." >&2
  exit 2
fi

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "CLAUDE_REVIEW_TIMEOUT_SECONDS must be a non-negative integer." >&2
  exit 2
fi

case "$MODE" in
  worktree|staged|branch|head)
    ;;
  *)
    if [[ $# -eq 1 ]]; then
      BASE="$MODE"
      MODE="branch"
    else
      usage
      exit 2
    fi
    ;;
esac

run_claude() {
  local input_file timeout_file pid watcher status

  input_file="$(mktemp "${TMPDIR:-/tmp}/claude-review.XXXXXX")"
  timeout_file="$(mktemp "${TMPDIR:-/tmp}/claude-review-timeout.XXXXXX")"
  rm -f "$timeout_file"

  cleanup_claude_review() {
    trap - RETURN

    if [[ -n "${watcher:-}" ]]; then
      kill "$watcher" >/dev/null 2>&1 || true
      wait "$watcher" 2>/dev/null || true
    fi

    if [[ -n "${pid:-}" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" 2>/dev/null || true
    fi

    rm -f "$input_file" "$timeout_file"
  }

  trap cleanup_claude_review RETURN

  cat >"$input_file"

  claude -p \
    --no-session-persistence \
    --output-format text \
    --tools="" \
    "$PROMPT" <"$input_file" &
  pid=$!

  if ((TIMEOUT_SECONDS > 0)); then
    (
      sleep "$TIMEOUT_SECONDS"
      if kill -0 "$pid" >/dev/null 2>&1; then
        : >"$timeout_file"
        kill "$pid" >/dev/null 2>&1 || true
      fi
    ) &
    watcher=$!
  else
    watcher=""
  fi

  if wait "$pid"; then
    status=0
  else
    status=$?
  fi

  if [[ -n "$watcher" ]]; then
    kill "$watcher" >/dev/null 2>&1 || true
    wait "$watcher" 2>/dev/null || true

    if [[ -e "$timeout_file" ]]; then
      echo "claude-review timed out after ${TIMEOUT_SECONDS}s." >&2
      status=124
    fi
  fi

  if ((status != 0)) && [[ ! -e "$timeout_file" ]]; then
    echo "claude CLI exited with status ${status}; review aborted." >&2
  fi

  return "$status"
}

case "$MODE" in
  worktree)
    git add -N .
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      DIFF_CMD=(git diff --unified="$CONTEXT_LINES" HEAD --)
    else
      DIFF_CMD=(git diff --unified="$CONTEXT_LINES" --)
    fi
    ;;
  staged)
    DIFF_CMD=(git diff --staged --unified="$CONTEXT_LINES")
    ;;
  branch)
    if ! git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null; then
      git fetch origin >/dev/null 2>&1 || true
    fi

    if ! git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null; then
      echo "Unknown base ref: $BASE" >&2
      exit 2
    fi

    MERGE_BASE="$(git merge-base "$BASE" HEAD)"
    DIFF_CMD=(git diff --unified="$CONTEXT_LINES" "$MERGE_BASE"...HEAD --)
    ;;
  head)
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
      echo "HEAD does not exist yet." >&2
      exit 2
    fi

    DIFF_CMD=(git show --format=fuller --stat --patch --unified="$CONTEXT_LINES" HEAD)
    ;;
esac

"${DIFF_CMD[@]}" | run_claude
