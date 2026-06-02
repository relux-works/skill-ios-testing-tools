#!/bin/bash
# Wrapper script for ios-device-build CLI
#
# Usage: ./ios-device-build.sh --workspace App.xcworkspace --scheme App [options]
#
# This script builds and runs the Swift CLI tool.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Build the CLI. SwiftPM is incremental; running this every time avoids using a
# stale release binary after source changes.
echo "Building ios-device-build..."
swift build -c release --package-path "$PACKAGE_DIR" --product ios-device-build

# Run the CLI
"$PACKAGE_DIR/.build/release/ios-device-build" "$@"
