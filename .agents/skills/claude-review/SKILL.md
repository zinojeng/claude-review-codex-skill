---
name: claude-review
description: Use the local Claude Code CLI on this Mac as an independent read-only reviewer for worktree, staged, branch, or last-commit git diffs. Trigger when the user asks Codex to ask Claude, use Claude Code, get a Claude second opinion, or run an adversarial project review.
---

# Claude Review

Use the local Claude Code CLI on this Mac as an independent read-only reviewer for code, docs, wiki, config, and other project diffs. Claude is a second opinion, not ground truth.

## Workflow

1. Verify `claude` is available with `claude auth status` or `claude -v`.
2. From the target Git worktree, run this skill's `scripts/claude-review.sh`.
3. Choose a mode:
   - `worktree`: review current working-tree changes against `HEAD`; this is the default.
   - `staged`: review only staged changes.
   - `branch <base>`: review `HEAD` against the merge base with `<base>`, such as `origin/main`.
   - `head`: review the latest commit.
4. For backward compatibility, passing only a base ref such as `main` is treated as `branch main`.
5. `worktree` mode runs `git add -N .` so untracked new files appear in the diff without staging content.
6. Do not ask Claude to edit files.
7. Summarize Claude's findings for the user as:
   - severity
   - file / line if available
   - issue
   - why it matters
   - suggested fix

This skill never writes project files; it produces a review report only. In `worktree` mode it may update the Git index with intent-to-add entries so new files are visible in `git diff`. Codex should implement fixes only when the user asks.
