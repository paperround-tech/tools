# Adding Colleague to Portal Bastion Hosts - Step by Step

## Current Bastion Setup

Each bastion host currently has 2 authorized SSH keys:
- **GitHub Actions** (for CI/CD)
- **Your personal key** (james.rothwellhughes@paperround.tech)

## Option 1: Add Colleague's Own Key (Recommended)

### Step 1: Colleague Generates SSH Key

Your colleague should run this on their Windows machine:

```powershell
# Generate new SSH key pair
ssh-keygen -t ed25519 -C "colleague.email@paperround.tech" -f ~/.ssh/bastion_key_portal

# This creates:
# - ~/.ssh/bastion_key_portal (private key)
# - ~/.ssh/bastion_key_portal.pub (public key)
```

### Step 2: Colleague Sends You Their Public Key

They should send you the content of their `.pub` file:

```powershell
# Windows - get public key content
Get-Content ~/.ssh/bastion_key_portal.pub
```

### Step 3: You Add Their Key to All Bastions

Run the script I created for you:

```bash
# Make sure you have their public key content
# Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... colleague@paperround.tech"

./add_colleague_to_bastions.sh "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... colleague@paperround.tech"
```

### Step 4: Colleague Updates Their Windows Scripts

They need to modify the PowerShell script configuration:

```powershell
# In portal-tunnels.ps1, change line 5 to:
$script:sshKeyBaseName = "bastion_key_portal"  # Use single key for all environments
```

### Step 5: Test Access

Your colleague should test access to one bastion:

```powershell
# Test SSH connection (should hang if successful, Ctrl+C to exit)
ssh -i ~/.ssh/bastion_key_portal ec2-user@35.179.170.3
```

---

## Option 2: Share Your Existing Keys (Simpler, Less Secure)

### Step 1: Copy Your Keys to Colleague

Send them copies of these files from your `~/.ssh/` directory:
- `bastion_key_qa`
- `bastion_key_uat`
- `bastion_key_staging`
- `bastion_key_production`

### Step 2: Colleague Places Keys in Windows

They should put the keys in `C:\Users\[username]\.ssh\`

### Step 3: Set Proper Permissions

```cmd
# Windows - set proper permissions
icacls %USERPROFILE%\.ssh\bastion_key_* /inheritance:r /grant:r %USERNAME%:R
```

### Step 4: Use Default Scripts

No script modifications needed - they can use the scripts as-is.

---

## Verification After Setup

### Check Bastion Access
```bash
# You can verify their key was added:
ssh -i ~/.ssh/bastion_key_qa ec2-user@35.179.170.3 "cat ~/.ssh/authorized_keys | wc -l"
# Should show 3 keys now (was 2 before)
```

### Test Tunnels
Your colleague should test the tunnel scripts:

```powershell
# Load the script
. .\portal-tunnels.ps1

# Test QA tunnel
portal-qa-tunnel

# Check status
portal-tunnel-list

# Stop tunnel
Stop-PortalTunnel -Environment qa
```

## Security Considerations

### Option 1 (Own Keys) - Recommended
✅ **Pros:**
- Each person has their own private key
- Can revoke access individually
- Better audit trail
- Follows security best practices

❌ **Cons:**
- Requires bastion configuration
- More setup steps

### Option 2 (Shared Keys) - Simpler
✅ **Pros:**
- No bastion configuration needed
- Immediate access
- Simple setup

❌ **Cons:**
- Shared private keys (security risk)
- Can't revoke individual access
- Harder to audit who accessed what

## Bastion Host Details

- **QA**: ec2-user@35.179.170.3 → port 5433
- **UAT**: ec2-user@18.175.239.214 → port 5434  
- **Staging**: ec2-user@52.56.142.14 → port 5435
- **Production**: ec2-user@18.170.58.57 → port 5436

## Troubleshooting

### Key Permission Issues
```cmd
# Windows - fix key permissions
icacls %USERPROFILE%\.ssh\bastion_key_* /inheritance:r /grant:r %USERNAME%:R
```

### SSH Connection Test
```bash
# Test direct SSH (should hang if working)
ssh -v -i ~/.ssh/bastion_key_portal ec2-user@35.179.170.3
```

### Remove Colleague's Access Later
If you need to remove their access:

```bash
# Remove their key from each bastion
ssh -i ~/.ssh/bastion_key_qa ec2-user@35.179.170.3 "sed -i '/colleague@paperround.tech/d' ~/.ssh/authorized_keys"
ssh -i ~/.ssh/bastion_key_uat ec2-user@18.175.239.214 "sed -i '/colleague@paperround.tech/d' ~/.ssh/authorized_keys"
ssh -i ~/.ssh/bastion_key_staging ec2-user@52.56.142.14 "sed -i '/colleague@paperround.tech/d' ~/.ssh/authorized_keys"
ssh -i ~/.ssh/bastion_key_production ec2-user@18.170.58.57 "sed -i '/colleague@paperround.tech/d' ~/.ssh/authorized_keys"
```
