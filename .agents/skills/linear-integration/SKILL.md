---
name: linear-integration
description: >
  Cross-project Linear issue tracking workflow. Use this skill when creating issues, starting
  work on issues, creating PRs linked to issues, checking issue status, or any workflow involving
  Linear. Project-level skills may specify the team prefix and target branch.
---

# Linear Integration

The `linear` CLI (v1.7.0) is installed at `~/.deno/bin/linear`.

## Workflow: New Issue → Branch → Fix → PR

### 1. Create an issue
```
linear issue create -t "Title" -d "Description" -a self --start
```
`--start` creates a branch and checks it out. Branch name follows `feature/<ticket>-<slug>`.

Useful flags: `-l <label>`, `--priority <1-4>`, `--estimate <points>`, `-p <parent-issue>`, `--team <TEAM>`.

### 2. Start an existing issue
```
linear issue start [issueId]
```
Creates a feature branch and checks it out. Use `-f <ref>` to branch from a specific ref.

### 3. Create a PR
```
linear issue pr --base develop --draft
```
Creates a GitHub PR linked to the current branch's issue. Use `--draft` for work-in-progress.

## Quick Reference
- `linear issue id` — get issue ID from current branch
- `linear issue view [id]` — view issue details
- `linear issue view [id] --web` — open in browser
- `linear issue list` — list your assigned issues
- `linear issue update [id] -s "Done"` — update issue state
- `linear issue comment [id]` — manage comments
- `linear issue describe [id]` — get title + trailer for commit messages

## Conventions
- Feature branches are created by Linear via `linear issue start` or `--start` — never manually.
- When committing, extract the ticket ID from the branch name and include it in the commit message.
- Always include `Co-Authored-By: Oz <oz-agent@warp.dev>` in commits.

## Integration with Fixes
1. If no Linear issue exists yet, offer to create one with `linear issue create --start`.
2. If on the wrong branch, use `linear issue start <id>` to switch.
3. Stage, commit (with ticket ID), push, and offer to create a PR.
