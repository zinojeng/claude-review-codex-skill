# Claude Review Codex Skill

Repo-local Codex skill for asking the local Claude Code CLI to perform an independent read-only review of a Git diff.

## Usage

From a target Git worktree:

```bash
/path/to/.agents/skills/claude-review/scripts/claude-review.sh [base-ref]
```

Omit `base-ref` to review tracked working-tree changes against `HEAD`; pass a base ref such as `main` to review `main...HEAD`.
