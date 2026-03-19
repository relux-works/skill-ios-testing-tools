#!/usr/bin/env bash
# Setup skills locally in a project for Claude Code and Codex CLI
#
# Usage: ./setup-project-skills.sh /path/to/your/project
#
# Creates:
#   <project>/.agents/skills/ios-testing-tools/  ← installed skill copy
#   <project>/.claude/skills/ios-testing-tools   ← symlink
#   <project>/.codex/skills/ios-testing-tools    ← symlink

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_NAME="ios-testing-tools"
SOURCE_DIR="$REPO_DIR/agents/skills/$SKILL_NAME"

scrub_git_metadata() {
    local target_dir="$1"
    rm -rf "$target_dir/.git"
    rm -f "$target_dir/.gitignore" "$target_dir/.gitattributes" "$target_dir/.gitmodules"
}

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/your/project"
    exit 1
fi

PROJECT_DIR="$(cd "$1" && pwd)"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory not found: $1"
    exit 1
fi

echo "Setting up skills in: $PROJECT_DIR"

# Create directories
mkdir -p "$PROJECT_DIR/.agents/skills" "$PROJECT_DIR/.claude/skills" "$PROJECT_DIR/.codex/skills"

# Copy skill
if [ -d "$PROJECT_DIR/.agents/skills/$SKILL_NAME" ]; then
    echo "Removing existing .agents/skills/$SKILL_NAME"
    rm -rf "$PROJECT_DIR/.agents/skills/$SKILL_NAME"
fi
mkdir -p "$PROJECT_DIR/.agents/skills/$SKILL_NAME"
rsync -a --delete "$SOURCE_DIR/" "$PROJECT_DIR/.agents/skills/$SKILL_NAME/" --exclude='.git'
scrub_git_metadata "$PROJECT_DIR/.agents/skills/$SKILL_NAME"
echo "✓ Copied $SKILL_NAME to .agents/skills/"

# Create symlinks
for dir in .claude/skills .codex/skills; do
    target="$PROJECT_DIR/$dir/$SKILL_NAME"
    if [ -L "$target" ] || [ -e "$target" ]; then
        rm -rf "$target"
    fi
    ln -s "../../.agents/skills/$SKILL_NAME" "$target"
    echo "✓ Symlinked $dir/$SKILL_NAME"
done

# Remove hidden flags (macOS)
chflags nohidden "$PROJECT_DIR/.claude" 2>/dev/null || true
chflags nohidden "$PROJECT_DIR/.codex" 2>/dev/null || true
chflags nohidden "$PROJECT_DIR/.agents" 2>/dev/null || true

echo ""
echo "Done! Skill installed in $PROJECT_DIR"
echo ""
echo "Structure:"
echo "  .agents/skills/$SKILL_NAME/  ← installed skill copy"
echo "  .claude/skills/$SKILL_NAME   ← symlink (Claude Code)"
echo "  .codex/skills/$SKILL_NAME    ← symlink (Codex CLI)"
echo ""
echo "Installed copy is degitized after sync."
