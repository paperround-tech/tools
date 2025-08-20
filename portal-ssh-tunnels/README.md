# Portal SSH Tunnels

Cross-platform SSH tunnel scripts for connecting to Portal database environments via bastion hosts.

## Quick Start

### macOS/Linux
Source the functions in your shell:
```bash
# Add to your ~/.zshrc or ~/.bashrc
source /path/to/portal-ssh-tunnels/unix/portal-tunnels.sh

# Usage
portal-qa-tunnel
portal-tunnel-list
portal-tunnel-stop qa
```

### Windows (PowerShell)
```powershell
# Load the script
. .\windows\portal-tunnels.ps1

# Usage  
portal-qa-tunnel
portal-tunnel-list
Stop-PortalTunnel -Environment qa
```

### Windows (Command Prompt)
```cmd
# Usage
windows\portal-tunnels.bat start-qa
windows\portal-tunnels.bat list
windows\portal-tunnels.bat stop qa
```

## Environment Details

| Environment | Local Port | Bastion Host | RDS Cluster |
|-------------|------------|--------------|-------------|
| QA | 5433 | 35.179.170.3 | portal-qa-cluster |
| UAT | 5434 | 18.175.239.214 | portal-uat-cluster |
| Staging | 5435 | 52.56.142.14 | portal-staging-cluster |
| Production | 5436 | 18.170.58.57 | portal-production-cluster |

## Repository Structure

```
portal-ssh-tunnels/
├── README.md                    # This file
├── docs/
│   ├── WINDOWS_SETUP.md         # Detailed Windows setup instructions
│   └── COLLEAGUE_SETUP_STEPS.md # Step-by-step guide for adding new team members
├── windows/
│   ├── portal-tunnels.ps1       # PowerShell version (recommended)
│   └── portal-tunnels.bat       # Batch file version
├── unix/
│   └── portal-tunnels.sh        # Bash/Zsh shell script
└── scripts/
    └── add_colleague_to_bastions.sh # Script to add new users to bastion hosts
```

## Setup

### Prerequisites
1. SSH client installed
2. Bastion SSH keys in `~/.ssh/` (Unix) or `%USERPROFILE%\.ssh\` (Windows)
3. Proper key permissions set

### First Time Setup
1. **Get SSH keys** from team lead
2. **Follow platform-specific setup** in `docs/WINDOWS_SETUP.md`
3. **Test connection** to one bastion host
4. **Run tunnel scripts**

### Adding New Team Members
See `docs/COLLEAGUE_SETUP_STEPS.md` for detailed instructions on:
- Generating SSH keys
- Adding keys to bastion hosts
- Configuring scripts

## Database Connection

Once tunnels are running, connect to databases using:
- **Host**: `localhost`
- **Port**: Environment-specific (5433-5436)
- **Username/Password**: Your database credentials

Example connection strings:
```
# QA
postgresql://username:password@localhost:5433/portal_qa

# Production  
postgresql://username:password@localhost:5436/portal_production
```

## Security

- Keep SSH private keys secure
- Use individual SSH keys per team member (recommended)
- Stop tunnels when not in use
- Be especially careful with production access

## Troubleshooting

### Common Issues
1. **Port already in use** - Check for existing tunnels or processes
2. **Permission denied** - Verify SSH key permissions and bastion access
3. **Connection refused** - Check network connectivity and bastion host status

### Debugging
```bash
# Test SSH connection directly
ssh -v -i ~/.ssh/bastion_key_qa ec2-user@35.179.170.3

# Check running processes
ps aux | grep ssh
netstat -an | grep :5433
```

## Contributing

When adding new environments or modifying scripts:
1. Update all platform versions (PowerShell, batch, shell)
2. Update documentation
3. Test on both Windows and Unix systems
4. Commit with descriptive messages
