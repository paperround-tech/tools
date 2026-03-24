# Portal SSH Tunnels

Cross-platform SSH tunnel scripts for connecting to Portal database environments.

- **Development** uses an SSM relay (no SSH key required — just AWS SSO)
- **QA, UAT, Staging, Production** use SSH bastion hosts

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

| Environment | Local Port | Access Method | Notes |
|-------------|------------|---------------|-------|
| Development | 5437 | SSM relay — `portal-development-tunnel` | No SSH key — AWS SSO only |
| QA (SSM) | 5438 | SSM relay — future (DSY-129) | |
| UAT (SSM) | 5439 | SSM relay — `portal-uat-ssm-tunnel` | No SSH key — AWS SSO only |
| QA (SSH) | 5433 | SSH bastion 35.179.170.3 | |
| UAT (SSH) | 5434 | SSH bastion 18.175.239.214 | Legacy — use SSM tunnel instead |
| Staging | 5435 | SSH bastion 52.56.142.14 | |
| Production | 5436 | SSH bastion 18.170.58.57 | |

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

**Development (SSM relay)**
1. AWS CLI installed and configured
2. Active AWS SSO session: `aws sso login`
3. IAM permissions to `ssm:StartSession` on the relay instance and `PortForward-portal-development` document

**QA / UAT / Staging / Production (SSH bastion)**
1. SSH client installed
2. Bastion SSH keys in `~/.ssh/` (Unix) or `%USERPROFILE%\.ssh\` (Windows)
3. Proper key permissions set

### First Time Setup
1. **Development**: ensure AWS SSO is configured — no SSH key needed
2. **QA+**: get SSH keys from team lead, follow `docs/COLLEAGUE_SETUP_STEPS.md`
3. **Test**: run `portal-tunnel-list` after sourcing the script

### Adding New Team Members
See `docs/COLLEAGUE_SETUP_STEPS.md` for detailed instructions on:
- Generating SSH keys
- Adding keys to bastion hosts
- Configuring scripts

## Database Connection

Once tunnels are running, connect to databases using:
- **Host**: `localhost`
- **Port**: Environment-specific (see table above)
- **Username/Password**: Fetch from AWS SSM (never stored in files)

```bash
# Fetch credentials (example for development)
DEV_USER=$(aws ssm get-parameter --region eu-west-2 \
  --name /portal/development/database/main/username --with-decryption \
  --query 'Parameter.Value' --output text)
DEV_PASS=$(aws ssm get-parameter --region eu-west-2 \
  --name /portal/development/database/main/password --with-decryption \
  --query 'Parameter.Value' --output text)

# Connect
PGPASSWORD=$DEV_PASS psql -h localhost -p 5437 -U $DEV_USER -d portal_development
```

SSM parameter paths follow the pattern: `/portal/{environment}/database/main/{username|password}`

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
