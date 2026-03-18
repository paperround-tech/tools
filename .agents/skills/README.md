# Global Agent Skills

These skills are available across **all projects** on this machine. They define cross-project conventions and workflows that Warp's Oz agent follows automatically.

## Skills

| Directory | Purpose |
|-----------|---------|
| `git-workflow/` | Merge strategy, branching, commit conventions, branch comparison |
| `cli-environment/` | Pager settings, AWS region, GitHub CLI, Linear CLI |
| `linear-integration/` | Issue → branch → fix → PR workflow using the Linear CLI |
| `github-repo-setup/` | Standards for new repos: merge strategy, branch protection, defaults |

## How It Works

**Global skills** (`~/.agents/skills/`) apply to every project. They define universal rules.

**Project skills** (`<repo>/.agents/skills/`) extend globals with repo-specific details (team prefixes, tunnel ports, environment promotion order, etc.). They reference the global skills by name.

When working in a project, Oz sees both layers. Global skills provide the foundation; project skills add specifics.

## Sharing With a New Machine

Copy `~/.agents/skills/` to the home directory of any machine:

```bash
# From this machine
rsync -av ~/.agents/skills/ <user>@<host>:~/.agents/skills/

# Or clone from a dotfiles repo
git clone <dotfiles-repo> ~/dotfiles
ln -s ~/dotfiles/.agents ~/.agents
```

## Sharing With a Team

Option 1: **Dotfiles repo** — version-control `~/.agents/` in a personal dotfiles repo. Each team member clones their own copy.

Option 2: **Shared repo** — create a dedicated `team-skills` repo. Each developer symlinks or copies the skills to their home directory.

Option 3: **Project bootstrap** — include a setup script in each project that copies/symlinks the global skills from the repo into `~/.agents/skills/` if they don't already exist.

## Adding a New Skill

```bash
mkdir -p ~/.agents/skills/<skill-name>
# Create SKILL.md with YAML frontmatter (name + description) and markdown instructions
```

See any existing skill for the format. The `name` in frontmatter should match the directory name.

## Relationship to Warp Rules

**Rules** = persistent constraints the agent always follows (preferences, guardrails).
**Skills** = specific task workflows the agent invokes when relevant.

Both can be global or project-scoped. Use rules for "always do X", skills for "here's how to do Y".
