# PPR Development Tools

A collection of development tools and utilities for the PPR (PaperRound) project.

## Tools

### [Portal SSH Tunnels](./portal-ssh-tunnels/)
Cross-platform SSH tunnel scripts for connecting to Portal database environments via bastion hosts.

**Platforms**: Windows (PowerShell, Batch), macOS/Linux (Bash/Zsh)

**Quick Start**:
```bash
# macOS/Linux
source portal-ssh-tunnels/unix/portal-tunnels.sh
portal-qa-tunnel

# Windows PowerShell
. .\portal-ssh-tunnels\windows\portal-tunnels.ps1
portal-qa-tunnel
```

**Environments**: QA (5433), UAT (5434), Staging (5435), Production (5436)

## Repository Structure

```
tools/
├── README.md                    # This file
├── portal-ssh-tunnels/         # SSH tunnel utilities
│   ├── README.md
│   ├── docs/                    # Documentation
│   ├── windows/                 # Windows scripts (PowerShell, Batch)
│   ├── unix/                    # Unix scripts (Bash/Zsh)
│   └── scripts/                 # Admin scripts
└── [future tools...]           # Additional tools will go here
```

## Contributing

When adding new tools:

1. **Create a new directory** for your tool (e.g., `database-utils/`, `deployment-scripts/`)
2. **Include a README.md** with setup and usage instructions
3. **Support multiple platforms** where applicable (Windows/Unix)
4. **Add entry** to this main README
5. **Follow consistent structure**:
   ```
   your-tool/
   ├── README.md
   ├── docs/           # Detailed documentation
   ├── windows/        # Windows-specific files (if applicable)
   ├── unix/           # Unix-specific files (if applicable)
   └── scripts/        # Utility/admin scripts
   ```

## Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/paperround-tech/tools.git ppr-tools
   cd ppr-tools
   ```

2. **Choose your tool** and follow its specific README

3. **Set up platform-specific requirements** as documented

## Security

- **Never commit secrets** (SSH keys, passwords, tokens)
- **Use `.gitignore`** to exclude sensitive files
- **Follow least-privilege principle** for access controls
- **Document security requirements** in tool READMEs

## Support

For tool-specific issues, check the individual tool's README and documentation.

For general questions about this repository, contact the development team.

## Future Tools

Planned additions:
- Database migration utilities
- Deployment automation scripts
- Log analysis tools
- Environment configuration helpers
- Testing utilities
