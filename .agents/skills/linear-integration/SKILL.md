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
linear issue create -t "Title" -d "Description" --team <TEAM>
```
Creates the issue and prints its URL (e.g. `DSY-125`).

Useful flags: `-l <label>`, `--priority <1-4>`, `--estimate <points>`, `-p <parent-issue>`, `--team <TEAM>`, `-s <state>`.

**Important:** Do NOT use `--start` or `-a self` — the `--start` flag internally tries to resolve the assignee via `self` which fails in non-interactive/agent contexts. Instead, create the issue first, then start it separately (see step 2).

### 2. Start an issue (create branch + set In Progress)
```
linear issue start <issueId>
```
Creates a feature branch, checks it out, and sets the issue to In Progress.
Use `-f <ref>` to branch from a specific ref.

**Two-step create-and-start pattern:**
```
linear issue create -t "Title" -d "Description" --team DSY
# note the issue ID from the output URL (e.g. DSY-125)
linear issue start DSY-125
```

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
- Feature branches are created by Linear via `linear issue start` — never manually.
- When committing, extract the ticket ID from the branch name and include it in the commit message.
- Always include `Co-Authored-By: Oz <oz-agent@warp.dev>` in commits.

## Integration with Fixes
1. If no Linear issue exists yet, create one with `linear issue create`, then `linear issue start <id>`.
2. If on the wrong branch, use `linear issue start <id>` to switch.
3. Stage, commit (with ticket ID), push, and offer to create a PR.
