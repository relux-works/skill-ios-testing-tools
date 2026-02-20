#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="ios-testing-tools"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_CONTENT_DIR="$REPO_DIR/agents/skills/ios-testing-tools"

AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.codex/skills"

echo "Installing skill: $SKILL_NAME"
echo "  Source: $SKILL_CONTENT_DIR"

# 1. Copy skill into .agents/skills/ (installed copy, not a symlink)
if [ -L "$AGENTS_DIR/$SKILL_NAME" ]; then
  rm -f "$AGENTS_DIR/$SKILL_NAME"
fi
mkdir -p "$AGENTS_DIR/$SKILL_NAME"
rsync -a --delete "$SKILL_CONTENT_DIR/" "$AGENTS_DIR/$SKILL_NAME/" --exclude='.git'
echo "  Copied -> $AGENTS_DIR/$SKILL_NAME/"

# 2. Symlink from .claude/skills/ -> .agents/skills/
mkdir -p "$CLAUDE_DIR"
rm -f "$CLAUDE_DIR/$SKILL_NAME"
ln -s "$AGENTS_DIR/$SKILL_NAME" "$CLAUDE_DIR/$SKILL_NAME"
echo "  Symlink -> $CLAUDE_DIR/$SKILL_NAME"

# 3. Symlink from .codex/skills/ -> .agents/skills/
mkdir -p "$CODEX_DIR"
rm -f "$CODEX_DIR/$SKILL_NAME"
ln -s "$AGENTS_DIR/$SKILL_NAME" "$CODEX_DIR/$SKILL_NAME"
echo "  Symlink -> $CODEX_DIR/$SKILL_NAME"

echo ""
echo "Done. Installed $(git -C "$REPO_DIR" describe --tags --always 2>/dev/null || echo 'unknown')"
