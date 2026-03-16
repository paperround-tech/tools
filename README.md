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
- Installs npm dependencies for Node.js tools (e.g. `hnddb-queries`)
- Is idempotent — safe to re-run after pulling new changes
- Backs up any existing local skill directories before replacing with symlinks

Run `./scripts/setup.sh status` at any time to check your setup.

## Prerequisites

- **AWS SSO** — most tools need AWS credentials: `aws sso login --profile paperround`
- **Node.js** — required for `hnddb-queries` and other TypeScript tools
- **Warp terminal** — required for agent skills (skills are Warp-specific)

## Tools

### [Portal SSH Tunnels](./portal-ssh-tunnels/)
Cross-platform SSH tunnel scripts for connecting to Portal database environments via bastion hosts.

```bash
# macOS/Linux
source portal-ssh-tunnels/unix/portal-tunnels.sh
portal-qa-tunnel

# Windows PowerShell
. .\portal-ssh-tunnels\windows\portal-tunnels.ps1
portal-qa-tunnel
```

**Environments**: QA (5433), UAT (5434), Staging (5435), Production (5436). See [portal-ssh-tunnels/README.md](./portal-ssh-tunnels/README.md) for full docs.

### [HNDDB Queries](./hnddb-queries/)
TypeScript scripts for querying the PPR live replica MySQL database (`hnddb`). Credentials are fetched from AWS SSM automatically.

```bash
npx tsx hnddb-queries/query-db.ts "SELECT id, name FROM shops LIMIT 5"
```

**Scripts**: `query-db.ts` (live config, `/appconfig/live`), `query-mercury.ts` (mercury config, `/appconfig/mercury`). See [hnddb-queries/README.md](./hnddb-queries/README.md) for full docs.

## Agent Skills

This repo is the source of truth for the team's [Warp agent skills](https://docs.warp.dev/agent-platform/capabilities/skills). Skills are stored in `.agents/skills/` and symlinked into `~/.agents/skills/` by the setup script, making them globally available in every project.

**Current skills:**

| Skill | Purpose |
|-------|--------|
| `ppr-live-db` | Query the PPR live replica MySQL database. Includes data model reference docs for core tables, rounds, deliveries, training rounds, etc. |
| `aws-sso-manage` | Manage AWS SSO users, permission sets, and IAM migration |
| `cli-environment` | CLI environment preferences and setup |
| `git-workflow` | Git workflow conventions and branching strategy |
| `github-repo-setup` | GitHub repository configuration and branch protection |
| `linear-integration` | Linear issue tracking integration |

### Adding a new skill

1. Create a directory: `.agents/skills/your-skill-name/`
2. Add a `SKILL.md` with YAML frontmatter (`name` and `description` fields)
3. For large skills, split domain knowledge into supporting files (e.g. `data-model-*.md`) and reference them from `SKILL.md`
4. Update this README's skills table
5. Commit and push — teammates run `git pull && ./scripts/setup.sh skills` to pick it up

### Maintaining skills

After pulling changes that include skill updates, re-run setup to refresh symlinks:

```bash
git pull
./scripts/setup.sh skills
```

Skills are already symlinked, so content changes take effect immediately. The re-run is only needed when new skills are added.

## Setup Script Reference

```bash
./scripts/setup.sh          # Full setup (skills + dependencies)
./scripts/setup.sh skills   # Symlink skills only
./scripts/setup.sh deps     # Install tool dependencies only
./scripts/setup.sh status   # Show current setup status
```

## Repository Structure

```
tools/
├── .agents/skills/             # AI agent skills (symlinked globally)
│   ├── ppr-live-db/            # PPR database skill + data model docs
│   ├── aws-sso-manage/
│   ├── cli-environment/
│   ├── git-workflow/
│   ├── github-repo-setup/
│   └── linear-integration/
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
