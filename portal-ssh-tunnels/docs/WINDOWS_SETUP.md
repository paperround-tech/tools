# Portal SSH Tunnels - Windows Setup Guide

This guide helps you set up SSH tunnels to Portal databases on Windows systems.

## Prerequisites

1. **SSH Client**: Windows 10/11 includes OpenSSH client by default. To verify:
   ```cmd
   ssh -V
   ```
   If not available, install it via "Optional Features" or use [Git for Windows](https://git-scm.com/download/win).

2. **SSH Keys**: You need the bastion keys in your `%USERPROFILE%\.ssh\` directory:
   - `bastion_key_qa`
   - `bastion_key_uat` 
   - `bastion_key_staging`
   - `bastion_key_production`

3. **Key Permissions**: Set proper permissions on your SSH keys:
   ```cmd
   icacls %USERPROFILE%\.ssh\bastion_key_* /inheritance:r /grant:r %USERNAME%:R
   ```

## Installation Options

### Option 1: PowerShell (Recommended)

1. Copy `portal-tunnels.ps1` to a directory in your PATH or create a dedicated folder like `C:\Scripts\`

2. **Set Execution Policy** (one-time setup):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Load the script** in your PowerShell profile or run it manually:
   ```powershell
   # Load once per session
   . .\portal-tunnels.ps1
   
   # Or add to your PowerShell profile for automatic loading
   Add-Content $PROFILE ". C:\path\to\portal-tunnels.ps1"
   ```

### Option 2: Command Prompt / Batch File

1. Copy `portal-tunnels.bat` to a directory in your PATH (like `C:\Windows\System32` or create `C:\Scripts\` and add to PATH)

2. Use directly from Command Prompt

## Usage

### PowerShell Commands

```powershell
# Start individual tunnels
portal-qa-tunnel                    # or Start-PortalQATunnel
portal-uat-tunnel                   # or Start-PortalUATTunnel  
portal-staging-tunnel               # or Start-PortalStagingTunnel
portal-production-tunnel            # or Start-PortalProductionTunnel

# Management commands
portal-tunnel-start-all             # or Start-AllPortalTunnels
portal-tunnel-stop-all              # or Stop-AllPortalTunnels
Stop-PortalTunnel -Environment qa   # Stop specific tunnel
portal-tunnel-list                  # or Get-PortalTunnelStatus

# Help
Show-PortalTunnelHelp
```

### Batch File Commands

```cmd
# Start individual tunnels
portal-tunnels.bat start-qa
portal-tunnels.bat start-uat
portal-tunnels.bat start-staging
portal-tunnels.bat start-production

# Management commands
portal-tunnels.bat start-all
portal-tunnels.bat stop-all
portal-tunnels.bat stop qa          # Stop specific tunnel
portal-tunnels.bat list

# Help
portal-tunnels.bat help
```

## Port Mappings

- **QA**: localhost:5433 → portal-qa-cluster (via 35.179.170.3)
- **UAT**: localhost:5434 → portal-uat-cluster (via 18.175.239.214)  
- **Staging**: localhost:5435 → portal-staging-cluster (via 52.56.142.14)
- **Production**: localhost:5436 → portal-production-cluster (via 18.170.58.57)

## Database Connection Examples

Once tunnels are running, connect to databases using localhost:

```
# QA Database
Host: localhost
Port: 5433
Username: your_db_username
Password: your_db_password
Database: portal_qa

# UAT Database  
Host: localhost
Port: 5434
Username: your_db_username
Password: your_db_password
Database: portal_uat
```

## Troubleshooting

### Common Issues

1. **"ssh: command not found"**
   - Install OpenSSH client through Windows Features or Git for Windows

2. **Permission denied (publickey)**
   - Check SSH key permissions: `icacls %USERPROFILE%\.ssh\bastion_key_qa`
   - Ensure key files are in the correct location

3. **Port already in use**
   - Check if tunnel is already running: `netstat -an | findstr :5433`
   - Kill existing processes or use different ports

4. **PowerShell execution policy error**
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Checking SSH Key Setup

```cmd
# Verify SSH keys exist
dir %USERPROFILE%\.ssh\bastion_key_*

# Test SSH connection (should hang if successful)
ssh -i %USERPROFILE%\.ssh\bastion_key_qa ec2-user@35.179.170.3
```

### Manual SSH Tunnel Command

If scripts don't work, try manual commands:

```cmd
# QA tunnel
ssh -N -L 5433:portal-qa-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 -o ExitOnForwardFailure=yes ec2-user@35.179.170.3 -i %USERPROFILE%\.ssh\bastion_key_qa
```

## Security Notes

- Keep SSH private keys secure and never share them
- Use strong passphrases for SSH keys
- Only run tunnels when needed
- Always stop tunnels when done working
- Be especially careful with production tunnels

## Support

If you encounter issues:
1. Verify SSH client installation
2. Check SSH key permissions and locations  
3. Test direct SSH connection to bastion hosts
4. Check Windows firewall settings
5. Verify network connectivity to AWS IPs
