#!/usr/bin/env bash
# Compatibility wrapper for the canonical global setup.
#
# Creates:
#   ~/.agents/skills/ios-testing-tools/  <- installed skill copy
#   ~/.claude/skills/ios-testing-tools   <- symlink
#   ~/.codex/skills/ios-testing-tools    <- symlink

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

exec "$REPO_DIR/setup.sh"
