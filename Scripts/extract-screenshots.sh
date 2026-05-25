#!/bin/bash
# Wrapper script for extract-screenshots CLI
#
# Usage: ./extract-screenshots.sh <path-to-xcresult> [output-dir]
#
# This script builds and runs the Swift CLI tool.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Build the CLI. SwiftPM is incremental; running this every time avoids using a
# stale release binary after source changes.
echo "Building extract-screenshots..."
swift build -c release --package-path "$PACKAGE_DIR" --product extract-screenshots

# Run the CLI
"$PACKAGE_DIR/.build/release/extract-screenshots" "$@"
