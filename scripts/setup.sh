#!/bin/bash

# PPR Tools Setup Script
#
# Sets up the development environment for the PPR tools repo:
# - Symlinks agent skills into ~/.agents/skills/ for global availability
# - Adds shell environment exports (GH_PAGER, AWS_PAGER) to ~/.zshrc
# - Adds source line for shell aliases to ~/.zshrc
# - Installs npm dependencies for Node.js-based tools
#
# Usage:
#   ./scripts/setup.sh          # Full setup
#   ./scripts/setup.sh skills   # Skills only
#   ./scripts/setup.sh env      # Shell environment exports only
#   ./scripts/setup.sh deps     # Dependencies only
#   ./scripts/setup.sh status   # Show current setup status
#
# Safe to re-run at any time (idempotent).

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the repo root (parent of scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SOURCE="$REPO_ROOT/.agents/skills"
SKILLS_TARGET="$HOME/.agents/skills"

# ─── Skills Setup ────────────────────────────────────────────────────────────

setup_skills() {
    echo -e "${BLUE}═══ Agent Skills Setup ═══${NC}"
    echo ""

    # Ensure target directory exists
    mkdir -p "$SKILLS_TARGET"

    local installed=0
    local updated=0
    local uptodate=0

    for skill_dir in "$SKILLS_SOURCE"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name=$(basename "$skill_dir")
        local target="$SKILLS_TARGET/$skill_name"
        local source_abs="$(cd "$skill_dir" && pwd)"

        if [ -L "$target" ]; then
            local current_link=$(readlink -f "$target")
            if [ "$current_link" = "$source_abs" ]; then
                echo -e "  ${GREEN}✓${NC} $skill_name (symlinked)"
                uptodate=$((uptodate + 1))
            else
                rm "$target"
                ln -s "$source_abs" "$target"
                echo -e "  ${YELLOW}↻${NC} $skill_name (symlink updated)"
                updated=$((updated + 1))
            fi
        elif [ -d "$target" ]; then
            # Replace old copy with symlink
            rm -rf "$target"
            ln -s "$source_abs" "$target"
            echo -e "  ${YELLOW}↻${NC} $skill_name (replaced copy with symlink)"
            updated=$((updated + 1))
        else
            ln -s "$source_abs" "$target"
            echo -e "  ${GREEN}+${NC} $skill_name (symlinked)"
            installed=$((installed + 1))
        fi
    done

    echo ""
    echo -e "  Skills: ${GREEN}$installed installed${NC}, ${YELLOW}$updated updated${NC}, $uptodate up to date"
    echo ""
}

# ─── Shell Environment ───────────────────────────────────────────────────────

setup_env() {
    echo -e "${BLUE}═══ Shell Environment Setup ═══${NC}"
    echo ""

    local shell_rc="$HOME/.zshrc"

    # Idempotently add an export line to ~/.zshrc
    add_export() {
        local export_line="$1"
        local marker="$2"
        if grep -qF "$marker" "$shell_rc" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $marker (already set)"
        else
            echo "$export_line" >> "$shell_rc"
            echo -e "  ${GREEN}+${NC} $marker (added to .zshrc)"
        fi
    }

    # Disable pagers for CLI tools (prevents broken pipe in non-interactive contexts)
    add_export 'export GH_PAGER=""' 'GH_PAGER'
    add_export 'export AWS_PAGER=""' 'AWS_PAGER'

    echo ""
}

# ─── Shell Aliases ───────────────────────────────────────────────────────────

setup_aliases() {
    echo -e "${BLUE}═══ Shell Aliases Setup ═══${NC}"
    echo ""

    local aliases_file="$REPO_ROOT/shell/aliases.sh"
    local source_line="source \"$aliases_file\""
    local shell_rc="$HOME/.zshrc"

    if [ ! -f "$aliases_file" ]; then
        echo -e "  ${RED}✗${NC} shell/aliases.sh not found"
        echo ""
        return 1
    fi

    if grep -qF "$aliases_file" "$shell_rc" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} aliases already sourced in .zshrc"
    else
        echo "" >> "$shell_rc"
        echo "# PPR Tools" >> "$shell_rc"
        echo "$source_line" >> "$shell_rc"
        echo -e "  ${GREEN}+${NC} added source line to .zshrc"
    fi

    echo ""
}

# ─── Dependencies Setup ─────────────────────────────────────────────────────

setup_deps() {
    echo -e "${BLUE}═══ Dependencies Setup ═══${NC}"
    echo ""

    # hnddb-queries
    if [ -f "$REPO_ROOT/hnddb-queries/package.json" ]; then
        if [ -d "$REPO_ROOT/hnddb-queries/node_modules" ]; then
            echo -e "  ${GREEN}✓${NC} hnddb-queries (node_modules exists)"
        else
            echo -e "  ${YELLOW}⟳${NC} hnddb-queries (installing...)"
            (cd "$REPO_ROOT/hnddb-queries" && npm install --silent)
            echo -e "  ${GREEN}✓${NC} hnddb-queries (installed)"
        fi
    fi

    echo ""
}

# ─── Status ──────────────────────────────────────────────────────────────────

show_status() {
    echo -e "${BLUE}═══ PPR Tools Status ═══${NC}"
    echo ""
    echo -e "${BLUE}Skills:${NC}"

    for skill_dir in "$SKILLS_SOURCE"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name=$(basename "$skill_dir")
        local target="$SKILLS_TARGET/$skill_name"
        local source_abs="$(cd "$skill_dir" && pwd)"

        if [ -L "$target" ]; then
            local current_link=$(readlink -f "$target")
            if [ "$current_link" = "$source_abs" ]; then
                echo -e "  ${GREEN}✓${NC} $skill_name (symlinked)"
            else
                echo -e "  ${YELLOW}!${NC} $skill_name (symlink points elsewhere — re-run setup)"
            fi
        elif [ -d "$target" ]; then
            echo -e "  ${YELLOW}!${NC} $skill_name (copy, not symlinked — re-run setup)"
        else
            echo -e "  ${RED}✗${NC} $skill_name (not installed)"
        fi
    done

    echo ""
    echo -e "${BLUE}Tools:${NC}"

    if [ -d "$REPO_ROOT/hnddb-queries/node_modules" ]; then
        echo -e "  ${GREEN}✓${NC} hnddb-queries (deps installed)"
    else
        echo -e "  ${RED}✗${NC} hnddb-queries (deps not installed)"
    fi

    if [ -f "$REPO_ROOT/portal-ssh-tunnels/unix/portal-tunnels.sh" ]; then
        echo -e "  ${GREEN}✓${NC} portal-ssh-tunnels (available)"
    fi

    if [ -f "$REPO_ROOT/openvpn/vpn.ts" ]; then
        if [ -f "$REPO_ROOT/config.json" ]; then
            echo -e "  ${GREEN}✓${NC} openvpn (configured)"
        else
            echo -e "  ${YELLOW}!${NC} openvpn (available but no config.json — copy config.example.json)"
        fi
    fi

    echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────

case "${1:-all}" in
    skills)
        setup_skills
        ;;
    env)
        setup_env
        ;;
    deps)
        setup_deps
        ;;
    status)
        show_status
        ;;
    all)
        echo -e "${BLUE}═══ PPR Tools Setup ═══${NC}"
        echo -e "Repo: $REPO_ROOT"
        echo ""
        setup_skills
        setup_env
        setup_aliases
        setup_deps
        echo -e "${GREEN}Setup complete!${NC}"
        echo "Run './scripts/setup.sh status' to check setup at any time."
        ;;
    *)
        echo "Usage: $0 [skills|deps|status|all]"
        exit 1
        ;;
esac
