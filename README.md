# PPR Development Tools

Shared development tools, database query scripts, and AI agent skills for the PaperRound team.

## Getting Started

```bash
git clone https://github.com/paperround-tech/tools.git ~/ws/ppr/tech/tools
cd ~/ws/ppr/tech/tools
./scripts/setup.sh
```

That's it. The setup script handles everything:
- Symlinks all [agent skills](#agent-skills) into `~/.agents/skills/` for global availability
- Adds a source line to `~/.zshrc` for [shell aliases](#shell-aliases) (`vpn`, `query-db`, tunnel commands, etc.)
- Installs npm dependencies for Node.js tools (e.g. `hnddb-queries`)
- Is idempotent — safe to re-run after pulling new changes

Run `./scripts/setup.sh status` at any time to check your setup.

## Prerequisites

- **AWS SSO** — most tools need AWS credentials: `aws sso login --profile paperround`
- **Node.js** — required for `hnddb-queries` and other TypeScript tools
- **Warp terminal** — required for agent skills (skills are Warp-specific)

## Tools

### [OpenVPN](./openvpn/)
CLI tool for managing PPR OpenVPN connections with automatic failover between profiles.

```bash
vpn connect live
vpn status
vpn disconnect
```

**Environments**: live (primary, backup, backup2), test (primary). Config is per-user via the `openvpn` section in `config.json` (gitignored). Passwords fetched from AWS SSM at runtime. See [openvpn/README.md](./openvpn/README.md) for full docs.

### [HNDDB Queries](./hnddb-queries/)
TypeScript scripts for querying the PPR live replica MySQL database (`hnddb`). Credentials are fetched from AWS SSM automatically.

```bash
query-db "SELECT id, name FROM shops LIMIT 5"
```

**Scripts**: `query-db` (live config, `/appconfig/live`), `query-mercury` (mercury config, `/appconfig/mercury`). See [hnddb-queries/README.md](./hnddb-queries/README.md) for full docs.

### [Portal SSH Tunnels](./portal-ssh-tunnels/)
Cross-platform SSH tunnel scripts for connecting to Portal database environments via bastion hosts.

```bash
portal-qa-tunnel
portal-tunnel-list
portal-tunnel-stop qa
```

**Environments**: QA (5433), UAT (5434), Staging (5435), Production (5436). See [portal-ssh-tunnels/README.md](./portal-ssh-tunnels/README.md) for full docs.

## Agent Skills

This repo is the source of truth for the team's [Warp agent skills](https://docs.warp.dev/agent-platform/capabilities/skills). Skills are stored in `.agents/skills/` and symlinked into `~/.agents/skills/` by the setup script, making them globally available in every project.

**Current skills:**

| Skill | Purpose |
|-------|--------|
| `tools-setup` | Bootstrap: checks tools repo for upstream changes at conversation start, reminds user to pull + run setup if behind |
| `fastmd` | FastMD MCP knowledge base — reading/writing markdown docs in the team KB |
| `ppr-live-db` | Query the PPR live replica MySQL database. Includes data model reference docs for core tables, rounds, deliveries, training rounds, etc. |
| `ppr-git-conventions` | PPR-specific git rules and conventions |
| `aws-sso-manage` | Manage AWS SSO users, permission sets, and IAM migration |
| `cli-environment` | CLI environment preferences and setup |
| `git-workflow` | Git workflow conventions and branching strategy |
| `github-repo-setup` | GitHub repository configuration and branch protection |
| `linear-integration` | Linear issue tracking integration |
| `wsl-dev-setup` | New machine bootstrap: full WSL dev environment setup for PPR engineers |

### Adding a new skill

1. Create a directory: `.agents/skills/your-skill-name/`
2. Add a `SKILL.md` with YAML frontmatter (`name` and `description` fields)
3. For large skills, split domain knowledge into supporting files (e.g. `data-model-*.md`) and reference them from `SKILL.md`
4. Update this README's skills table
5. Commit and push — teammates run `git pull && ./scripts/setup.sh skills` to pick it up

### Maintaining skills

After pulling changes that include skill updates, re-run setup to refresh:

```bash
git pull
./scripts/setup.sh skills
```

Skills are symlinked (not copied), so existing skills update automatically on `git pull`. Re-running `setup.sh skills` is only needed to pick up newly added skills.

## Shell Aliases

The setup script adds a source line to `~/.zshrc` that loads aliases from `shell/aliases.sh`. After setup (or `source ~/.zshrc`), these are available globally:

| Alias | Command |
|-------|--------|
| `vpn <cmd>` | OpenVPN tool (`connect`, `disconnect`, `status`, `list`) |
| `query-db "SQL"` | Query PPR live replica (hnddb) |
| `query-mercury "SQL"` | Query via mercury config |
| `portal-qa-tunnel` | Start QA SSH tunnel (port 5433) |
| `portal-tunnel-list` | Show running tunnels |
| `zs` | Reload `~/.zshrc` |
| `ta` | `tig --all` |

Portal tunnel functions (`portal-*-tunnel`, `portal-tunnel-stop`, etc.) are also loaded automatically.

## Setup Script Reference

```bash
./scripts/setup.sh          # Full setup (skills + aliases + dependencies)
./scripts/setup.sh skills   # Symlink skills only
./scripts/setup.sh deps     # Install tool dependencies only
./scripts/setup.sh status   # Show current setup status
```

## Repository Structure

```
tools/
├── .agents/skills/             # AI agent skills (symlinked globally)
│   ├── tools-setup/            # Conversation bootstrap: tools repo freshness check
│   ├── fastmd/                 # FastMD MCP knowledge base skill
│   ├── ppr-live-db/            # PPR database skill + data model docs
│   ├── ppr-git-conventions/    # PPR-specific git rules
│   ├── wsl-dev-setup/          # New machine setup for WSL
│   ├── aws-sso-manage/
│   ├── cli-environment/
│   ├── git-workflow/
│   ├── github-repo-setup/
│   └── linear-integration/
├── config.json                 # Per-user tool config (gitignored)
├── config.example.json         # Config template
├── shell/
│   └── aliases.sh              # Shell aliases (sourced from ~/.zshrc)
├── openvpn/                    # OpenVPN CLI tool with auto-failover
│   ├── README.md
│   └── vpn.ts
├── hnddb-queries/              # HNDDB MySQL query scripts
│   ├── README.md
│   ├── query-db.ts
│   ├── query-mercury.ts
│   └── package.json
├── portal-ssh-tunnels/         # SSH tunnel utilities
│   ├── README.md
│   ├── docs/
│   ├── unix/
│   ├── windows/
│   └── scripts/
├── scripts/
│   └── setup.sh                # Environment setup script
└── README.md
```

## Contributing

When adding new tools:

1. **Create a new directory** for your tool
2. **Include a README.md** with setup and usage instructions
3. **If the tool has dependencies**, add an install step to `scripts/setup.sh`
4. **Add an entry** to the Tools section of this README
5. Commit to `main` and let the team know to re-run setup

When adding new skills, follow the [Adding a new skill](#adding-a-new-skill) guide above.

## Security

- **Never commit secrets** (SSH keys, passwords, tokens)
- **Use `.gitignore`** to exclude sensitive files
- **Follow least-privilege principle** for access controls
- Credentials are always fetched at runtime from AWS SSM — nothing is stored locally
