---
name: ppr-git-conventions
description: >
  PPR organisation git branching conventions. Use this skill whenever referencing branches,
  creating agents, writing scripts, or giving advice about git workflows for the PPR codebase.
  Key facts: the integration branch is called 'development' (not 'develop'), and the production
  branch is 'main'. Feature branches are created by Linear.
---

# PPR Git Conventions

## Branch Names
- Integration branch: `development` (never `develop`)
- QA branch: `qa` — sits between `development` and `main` in the promotion flow
- Production branch: `main`
- Feature branches: created by Linear (named automatically from issue)

## Promotion Flow
feature branch → `development` → `qa` → `main`

## Notes
- `development`, `qa`, and `main` are protected and exist at the top level of all repos.
- Release branches are immutable — never force-push or rebase them.
- Never use rebase in git workflows; prefer merge.
