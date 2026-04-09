---
name: wsl-dev-setup
description: >
  Complete development machine setup for PPR engineers running WSL on Windows. Use this skill
  when onboarding a new developer, setting up a fresh WSL instance, or diagnosing a broken dev
  environment. Covers SSH keys, git config, workspace layout, tools repo setup, Node.js via nvm,
  and WSL-specific gotchas (e.g. Windows Node.js bleeding into PATH). Always use this skill
  when someone says they are setting up a new machine, a new WSL environment, or asks what they
  need to install to get started with PPR development.
---

# WSL Dev Machine Setup

Complete setup sequence for a new PPR development machine running WSL (Ubuntu) on Windows.
Work through the steps in order.

## Prerequisites

Check first:
- WSL is running Ubuntu (`cat /etc/os-release`)
- Internet access from WSL (`curl -I https://github.com`)
- Oh My Zsh installed (`grep oh-my-zsh ~/.zshrc`)

### Install Oh My Zsh (if missing)

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## Step 1: SSH Key

```bash
ssh-keygen -t ed25519 -C "github" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Add the public key to GitHub: **Settings → SSH and GPG keys → New SSH key**

Then test:

```bash
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
ssh -T git@github.com
# Expected: Hi <username>! You've successfully authenticated...
```

Persist the agent across sessions by adding this to `~/.zshrc` (after the `source $ZSH/oh-my-zsh.sh` line):

```bash
# SSH agent
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)"
fi
ssh-add ~/.ssh/id_ed25519 2>/dev/null
```

## Step 2: Git Config

```bash
git config --global user.name "First Lastname"
git config --global user.email "firstname.lastname@paperround.tech"
```

## Step 3: Workspace Structure

```bash
mkdir -p ~/ws/ppr/tech ~/ws/ppr/support
```

- `~/ws/ppr/tech/` — paperround-tech GitHub org repos
- `~/ws/ppr/support/` — SupportPaperround GitHub org repos

## Step 4: Node.js via nvm (do this BEFORE tools setup)

Windows Node.js bleeds into the WSL `$PATH` and breaks npm installs with UNC path errors.
Always install a native Linux Node via nvm — do this before running the tools setup script.

```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
export NVM_DIR="$HOME/.nvm" && \. "$NVM_DIR/nvm.sh"
nvm install --lts
```

Verify it's the Linux version (path must NOT start with `/mnt/c/`):

```bash
which node   # e.g. /home/<user>/.nvm/versions/node/v24.x.x/bin/node
node --version
```

nvm adds itself to `~/.zshrc` automatically.

## Step 5: Clone and Run Tools Repo

```bash
git clone git@github.com:paperround-tech/tools.git ~/ws/ppr/tech/tools
~/ws/ppr/tech/tools/scripts/setup.sh
```

This will:
- Symlink all agent skills into `~/.agents/skills/`
- Add a `shell/aliases.sh` source line to `~/.zshrc`
- Install npm dependencies for `hnddb-queries`

Verify everything is green:

```bash
~/ws/ppr/tech/tools/scripts/setup.sh status
```

## Step 6: Reload Shell

```bash
source ~/.zshrc
```

Check that aliases are available: `zs`, `ta`, `portal-qa-tunnel`, etc.

## Step 7: CLI Tools

Install all required CLI tools:

### apt packages

```bash
sudo apt-get update && sudo apt-get install -y tig openvpn unzip
```

### GitHub CLI (`gh`)

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install -y gh
```

Then authenticate:

```bash
gh auth login
```

### AWS CLI v2

```bash
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install
aws --version
```

### Deno + Linear CLI

```bash
curl -fsSL https://deno.land/install.sh | sh
export PATH="$HOME/.deno/bin:$PATH"
deno install -A --reload -f -g -n linear jsr:@schpet/linear-cli
```

Verify:

```bash
linear --version
```

Deno adds itself to `~/.zshrc` automatically.

The `GH_PAGER` and `AWS_PAGER` exports are handled automatically by `setup.sh` (Step 5).
No manual `.zshrc` edits needed for those.

## Step 8: AWS SSO

Most tools require AWS credentials. Configure SSO once:

```bash
aws configure sso
# Session name: paperround
# SSO start URL: https://paperround.awsapps.com/start
# SSO region: eu-west-1
# Default output: json
```

Daily login:

```bash
aws sso login --profile paperround
export AWS_PROFILE=paperround
```

See the `aws-sso-manage` skill for full user/permission-set details.

## WSL-Specific Gotchas

**Windows executables in PATH**: Windows `node`, `npm`, and `python` can shadow Linux versions.
Symptoms: commands invoke `C:\Windows\system32\cmd.exe`, or errors mention UNC paths
(`\\wsl.localhost\...`). Always install Linux-native versions (nvm for Node, apt for Python).

**Line endings**: If a shell script fails with `bad interpreter`, strip Windows CR characters:

```bash
sed -i 's/\r//' script.sh
```

**SSH agent across sessions**: The snippet added in Step 1 ensures the key is loaded on every
new terminal without spawning duplicate agents.

## Setup Checklist

- [ ] Oh My Zsh installed and configured
- [ ] SSH key generated and added to GitHub
- [ ] `ssh -T git@github.com` returns success
- [ ] Git `user.name` and `user.email` configured
- [ ] `~/ws/ppr/tech/` and `~/ws/ppr/support/` created
- [ ] Node.js installed via nvm (Linux-native)
- [ ] tools repo cloned to `~/ws/ppr/tech/tools`
- [ ] `setup.sh` completed without errors
- [ ] `setup.sh status` shows all green
- [ ] `tig`, `openvpn` installed via apt
- [ ] `gh` installed and authenticated (`gh auth login`)
- [ ] AWS CLI v2 installed (`aws --version`)
- [ ] Deno installed, Linear CLI installed (`linear --version`)
- [ ] `source ~/.zshrc` — aliases and all CLIs available
- [ ] AWS SSO configured
