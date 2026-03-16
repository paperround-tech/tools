---
name: git-workflow
description: >
  Cross-project git conventions and workflow rules. Use this skill when performing any git
  operations (branching, merging, committing, PR creation) or when discussing release/promotion
  workflows. Project-level skills may extend these rules with repo-specific details.
---

# Git Workflow

## Merge Strategy
- **Never rebase.** Always use merge commits (`git merge --no-ff`).
- GitHub repos must have squash merge and rebase merge **disabled** — only merge commits allowed.
- This preserves commit hashes across branches, making `git log` and visualisation tools accurate.

## Branch Conventions
- `main` and `develop` exist at the top level (not under a prefix).
- Feature branches follow `feature/<ticket>-<slug>` and are created by the issue tracker (Linear) — never manually.
- Release branches (e.g. `release/*`) are **immutable** — never push commits to them.

## Commit Messages
- Include the issue/ticket ID from the branch name where possible.
- Always include `Co-Authored-By: Oz <oz-agent@warp.dev>` when committing on behalf of the user.

## Pull Requests
- Never merge a PR if the QA environment is frozen (ask the user to confirm if unsure).
- Feature branches merge into `develop`.
- Never commit unless explicitly asked.

## Comparing Branches
- Use `git diff origin/develop..HEAD --stat` (content diff), **not** `git log origin/develop..HEAD` (commit log). Because feature/intermediate branches are promoted via merge PRs, commit hashes diverge even when content is identical. `git log` produces a misleading list of "ahead" commits.

## Build Safety
- Never build without asking the user for confirmation first.

## AWS Region
- Default working region is `eu-west-2` unless targeting a specific resource elsewhere.
