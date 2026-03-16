---
name: github-repo-setup
description: >
  Standards for configuring new GitHub repositories. Use this skill when creating a new repo,
  auditing repo settings, or setting up branch protection. Ensures consistent merge strategy,
  branch protection, and CI conventions across all projects.
---

# GitHub Repo Setup

## Merge Strategy
Only merge commits should be allowed. Disable squash and rebase:

```bash
gh api repos/{owner}/{repo} -X PATCH \
  -f allow_merge_commit=true \
  -f allow_squash_merge=false \
  -f allow_rebase_merge=false
```

**Why:** Squash merge creates new commit hashes, breaking `git log` comparisons between branches and making visualisation tools inaccurate. Merge commits preserve the full branch topology.

## Branch Protection (recommended)
For `develop` and `main`:

```bash
gh api repos/{owner}/{repo}/branches/{branch}/protection -X PUT \
  --input - <<EOF
{
  "required_status_checks": { "strict": true, "contexts": ["build", "test"] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null
}
EOF
```

Adjust `contexts` to match the repo's CI job names.

## Default Branch
- Default branch should be `develop` for active development repos.
- `main` is the production branch — only receives merges from release branches.

## Repository Checklist
When setting up a new repo:
1. Set merge strategy (merge commits only)
2. Configure branch protection on `develop` and `main`
3. Set default branch to `develop`
4. Add `.agents/skills/` directory with project-specific skills
5. Add `.linear.toml` with workspace and team config
6. Ensure CI workflow triggers on `develop` and feature branches
