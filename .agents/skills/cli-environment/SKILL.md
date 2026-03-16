---
name: cli-environment
description: >
  Cross-project CLI tool configuration and environment settings. Use this skill when running
  CLI commands (gh, aws, git, etc.) to ensure correct pager, region, and output settings.
  Also use when troubleshooting broken pipes, truncated output, or interactive prompts in
  non-interactive contexts.
---

# CLI Environment

## Pager Settings
CLI tools that auto-page output break in non-interactive contexts (agents, scripts, piped commands).
These environment variables are set in `~/.zshrc` to disable pagers globally:

- `GH_PAGER=""` — disables paging for the GitHub CLI (`gh`).
- `AWS_PAGER=""` — disables paging for the AWS CLI (`aws`).

When running `git` commands, always use the `--no-pager` global flag: `git --no-pager <command>`.

## AWS Region
Default working region is `eu-west-2`. Always use `--region eu-west-2` unless targeting a specific resource in another region.

## GitHub CLI (`gh`)
- Use `--json` with `--jq` for structured data extraction.
- Repo context is inferred from the working directory — no `--repo` needed.

## Linear CLI
- Binary: `~/.deno/bin/linear`
- API key exported in `~/.zshrc` as `LINEAR_API_KEY`.
- Workspace and team are configured per-project in `.linear.toml`.
