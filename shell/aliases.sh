#!/bin/bash
# PPR Tools — Shell Aliases
# Sourced from ~/.zshrc by the setup script.
# Updates come via git pull — no need to edit this manually.

# Resolve the tools repo root from this file's location
_PPR_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# OpenVPN
alias vpn="npx tsx $_PPR_TOOLS_DIR/openvpn/vpn.ts"

# HNDDB Queries
alias query-db="npx tsx $_PPR_TOOLS_DIR/hnddb-queries/query-db.ts"
alias query-mercury="npx tsx $_PPR_TOOLS_DIR/hnddb-queries/query-mercury.ts"

# Helpers
alias zs='source ~/.zshrc'
alias ta='tig --all'

# Portal SSH Tunnels
# shellcheck source=/dev/null
source "$_PPR_TOOLS_DIR/portal-ssh-tunnels/unix/portal-tunnels.sh" 2>/dev/null
