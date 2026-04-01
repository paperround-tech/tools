# OpenVPN Tool

CLI tool for managing PPR OpenVPN connections with automatic failover between profiles.

## Prerequisites

- **OpenVPN CLI:**
  - macOS: `brew install openvpn`
  - Linux: `sudo apt install openvpn` / `sudo yum install openvpn`
- **AWS SSO login:** `aws sso login --profile paperround`
- **Node.js / tsx** (used by all tools in this repo)
- **Passwordless sudo for OpenVPN** — OpenVPN needs root to create a TUN interface. To avoid password prompts, create a sudoers rule for the openvpn binary:
  ```bash
  # Use the path matching your openvpn_bin in config.json
  OVPN_BIN=/opt/homebrew/opt/openvpn/sbin/openvpn   # macOS (Homebrew)
  # OVPN_BIN=/usr/sbin/openvpn                       # Linux
  sudo sh -c "echo '$(whoami) ALL=(ALL) NOPASSWD: $OVPN_BIN' > /etc/sudoers.d/openvpn && chmod 440 /etc/sudoers.d/openvpn"
  ```
  This only grants passwordless access to the openvpn binary — nothing else.

## Setup

1. Copy the example config at the repo root and edit it:
   ```bash
   cp config.example.json config.json
   ```

2. Edit the `openvpn` section in `config.json`:
   - Set `ssm_password_path` to your SSM parameter path (e.g., `/openvpn/jamesrh`)
   - Add your `.ovpn` profile paths under each environment
   - Profiles are tried in order — put your preferred server first

   Your `.ovpn` profiles are typically in:
   ```
   ~/Library/Application Support/OpenVPN Connect/profiles/
   ```

3. To identify which `.ovpn` file maps to which server, check the `OVPN_ACCESS_SERVER_PROFILE` header in each file:
   ```bash
   grep OVPN_ACCESS_SERVER_PROFILE ~/Library/Application\ Support/OpenVPN\ Connect/profiles/*.ovpn
   ```

## Usage

After running `./scripts/setup.sh`, the `vpn` alias is available globally:

```bash
vpn connect live      # Connect to live (auto-failover between profiles)
vpn connect test      # Connect to test
vpn status            # Check connection status
vpn disconnect        # Disconnect (prompts for sudo)
vpn list              # List environments and profiles
vpn help              # Show help
```

### Auto-failover

When connecting to an environment with multiple profiles (e.g., live), the tool tries each profile in order. If a connection times out (default 15s), it automatically moves to the next profile. This handles cases where a server has reached its connection limit.

## Configuration

The `openvpn` section in the top-level `config.json`:

```json
{
  "openvpn": {
    "openvpn_bin": "/opt/homebrew/opt/openvpn/sbin/openvpn",
    "connect_timeout": 15,
    "ssm_password_path": "/openvpn/<username>",
    "environments": {
      "live": {
        "profiles": [
          { "name": "primary", "path": "/path/to/live.ovpn" },
          { "name": "backup", "path": "/path/to/backup.ovpn" }
        ]
      }
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `openvpn_bin` | Path to the openvpn binary |
| `connect_timeout` | Seconds to wait before trying next profile |
| `ssm_password_path` | AWS SSM parameter path for your OpenVPN password (region: eu-west-1) |
| `environments` | Map of environment names to profile lists |

## Security

- Passwords are fetched from AWS SSM at runtime — never stored locally
- Credentials are passed to OpenVPN via FIFO (named pipe) — never written to disk
- `config.json` lives at the repo root (gitignored) and is shared across all tools
- Requires `sudo` for OpenVPN (creates TUN network interface)
