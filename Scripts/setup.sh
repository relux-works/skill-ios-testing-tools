#!/usr/bin/env zsh
#
# Setup script for ios-testing-tools skill.
# Creates symlinks into ~/.agents/skills/, ~/.claude/skills/, ~/.codex/skills/.
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="ios-testing-tools"
SKILL_DIR="$REPO_DIR/agents/skills/$SKILL_NAME"
AGENTS_SKILLS="$HOME/.agents/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"

# --- Colors ---
red()   { print -P "%F{red}$1%f" }
green() { print -P "%F{green}$1%f" }
yellow(){ print -P "%F{yellow}$1%f" }

# --- Create symlink (replace if exists) ---
create_symlink() {
  local target="$1"
  local link="$2"

  if [[ -L "$link" ]]; then
    rm "$link"
    yellow "Replaced existing symlink: $link"
  elif [[ -d "$link" ]]; then
    yellow "Skipping $link (real directory exists — remove manually if needed)"
    return
  fi

  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"
  green "Created symlink: $link -> $target"
}

# --- Run ---
print ""
green "=== ios-testing-tools skill setup ==="
print ""

# 1. Symlink into ~/.agents/skills/
create_symlink "$SKILL_DIR" "$AGENTS_SKILLS/$SKILL_NAME"

# 2. Symlink into ~/.claude/skills/
create_symlink "$AGENTS_SKILLS/$SKILL_NAME" "$CLAUDE_SKILLS/$SKILL_NAME"

# 3. Symlink into ~/.codex/skills/
create_symlink "$AGENTS_SKILLS/$SKILL_NAME" "$CODEX_SKILLS/$SKILL_NAME"

# --- Verify ---
print ""
green "Verifying..."

verify() {
  local link="$1"
  if [[ -L "$link" ]] && [[ -e "$link" ]]; then
    green "  OK: $link"
  elif [[ -L "$link" ]]; then
    red "  BROKEN: $link (dangling symlink)"
  else
    red "  MISSING: $link"
  fi
}

verify "$AGENTS_SKILLS/$SKILL_NAME"
verify "$CLAUDE_SKILLS/$SKILL_NAME"
verify "$CODEX_SKILLS/$SKILL_NAME"

# Check SKILL.md is reachable
if [[ -f "$CLAUDE_SKILLS/$SKILL_NAME/SKILL.md" ]]; then
  green "  SKILL.md reachable via Claude Code"
else
  red "  SKILL.md NOT reachable via Claude Code"
fi

print ""
green "=== Done ==="
