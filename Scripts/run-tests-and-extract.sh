#!/bin/bash
# Run UI tests and extract screenshots in one command
#
# Usage: ./run-tests-and-extract.sh -workspace App.xcworkspace -scheme App [-destination "..."] [-output dir]
#
# Screenshots are extracted to .temp/{timestamp}_screenshots/ by default (relative to CWD)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
DESTINATION="platform=iOS Simulator,name=iPhone 16"
OUTPUT_DIR=""

# Parse arguments
XCODEBUILD_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -destination)
            DESTINATION="$2"
            shift 2
            ;;
        -output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            XCODEBUILD_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ ${#XCODEBUILD_ARGS[@]} -eq 0 ]; then
    echo "Usage: $0 -workspace App.xcworkspace -scheme App [-destination \"...\"] [-output dir]"
    echo ""
    echo "Options:"
    echo "  -workspace    Xcode workspace path"
    echo "  -scheme       Build scheme name"
    echo "  -destination  Simulator destination (default: iPhone 16)"
    echo "  -output       Output directory for screenshots (default: .temp/{timestamp}_screenshots)"
    echo ""
    echo "All paths are relative to current working directory."
    echo ""
    echo "Example:"
    echo "  $0 -workspace MyApp.xcworkspace -scheme MyApp"
    echo "  $0 -workspace MyApp.xcworkspace -scheme MyApp -output .temp/screenshots"
    echo "  $0 -workspace MyApp.xcworkspace -scheme MyApp -destination \"platform=iOS Simulator,name=iPhone 15 Pro\""
    exit 1
fi

# Set default output dir if not specified
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=".temp/${TIMESTAMP}_screenshots"
fi

RESULTS_DIR="$(pwd)/.temp"
RESULT_BUNDLE_PATH="$RESULTS_DIR/latest.xcresult"

mkdir -p "$RESULTS_DIR"

echo "═══════════════════════════════════════════════════════════════"
echo "Running UI tests..."
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Run tests
xcodebuild test \
    "${XCODEBUILD_ARGS[@]}" \
    -destination "$DESTINATION" \
    -resultBundlePath "$RESULT_BUNDLE_PATH" \
    | xcpretty || true

echo "xcresult: $RESULT_BUNDLE_PATH"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Extracting screenshots..."
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build extract tool if needed
if [ ! -f "$PACKAGE_DIR/.build/release/extract-screenshots" ]; then
    echo "Building extract-screenshots..."
    swift build -c release --package-path "$PACKAGE_DIR" --product extract-screenshots
fi

# Extract screenshots
"$PACKAGE_DIR/.build/release/extract-screenshots" "$RESULT_BUNDLE_PATH" "$OUTPUT_DIR"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Done!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Screenshots: $OUTPUT_DIR"
echo ""
echo "Review with:"
echo "  open $OUTPUT_DIR"
echo "  # or use Claude/Codex Read tool to inspect PNGs"
