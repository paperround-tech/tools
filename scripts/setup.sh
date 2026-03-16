#!/bin/bash

# PPR Tools Setup Script
#
# Sets up the development environment for the PPR tools repo:
# - Copies agent skills into ~/.agents/skills/ for global availability
# - Installs npm dependencies for Node.js-based tools
#
# Usage:
#   ./scripts/setup.sh          # Full setup
#   ./scripts/setup.sh skills   # Skills only (re-run after pulling skill changes)
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

        if [ -L "$target" ]; then
            # Remove stale symlink from previous setup approach
            rm "$target"
            cp -r "$skill_dir" "$target"
            echo -e "  ${YELLOW}↻${NC} $skill_name (replaced symlink with copy)"
            updated=$((updated + 1))
        elif [ -d "$target" ]; then
            # Check if content has changed
            if diff -rq "$skill_dir" "$target" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $skill_name (up to date)"
                uptodate=$((uptodate + 1))
            else
                rm -rf "$target"
                cp -r "$skill_dir" "$target"
                echo -e "  ${YELLOW}↻${NC} $skill_name (updated)"
                updated=$((updated + 1))
            fi
        else
            cp -r "$skill_dir" "$target"
            echo -e "  ${GREEN}+${NC} $skill_name (installed)"
            installed=$((installed + 1))
        fi
    done

    echo ""
    echo -e "  Skills: ${GREEN}$installed installed${NC}, ${YELLOW}$updated updated${NC}, $uptodate up to date"
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

        if [ -d "$target" ]; then
            if diff -rq "$skill_dir" "$target" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $skill_name (up to date)"
            elif [ -L "$target" ]; then
                echo -e "  ${YELLOW}!${NC} $skill_name (stale symlink — re-run setup)"
            else
                echo -e "  ${YELLOW}!${NC} $skill_name (out of date — re-run setup)"
            fi
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

    echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────

case "${1:-all}" in
    skills)
        setup_skills
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
        setup_deps
        echo -e "${GREEN}Setup complete!${NC}"
        echo "Run './scripts/setup.sh status' to check setup at any time."
        ;;
    *)
        echo "Usage: $0 [skills|deps|status|all]"
        exit 1
        ;;
esac
