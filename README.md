# Claude Review Codex Skill

Repo-local Codex skill for asking the local Claude Code CLI to perform an independent review of a Git diff.

## Usage

From a target Git worktree:

```bash
/path/to/.agents/skills/claude-review/scripts/claude-review.sh [worktree|staged|branch|head] [base-ref]
```

Modes:

- `worktree`: review current working-tree changes against `HEAD`; this is the default.
- `staged`: review only staged changes.
- `branch <base-ref>`: review `HEAD` against the merge base with `<base-ref>`, such as `origin/main`.
- `head`: review the latest commit.

For backward compatibility, passing only a base ref still works:

```bash
/path/to/.agents/skills/claude-review/scripts/claude-review.sh main
```

That is treated as:

```bash
/path/to/.agents/skills/claude-review/scripts/claude-review.sh branch main
```
