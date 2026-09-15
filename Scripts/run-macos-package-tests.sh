#!/bin/bash
# Native macOS Swift package unit/integration tests. Does not launch XCUITest.
set -euo pipefail
package=""
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --package) package="${2:?--package needs a directory}"; shift 2 ;;
    --output) output="${2:?--output needs a directory}"; shift 2 ;;
    --help) echo 'Usage: run-macos-package-tests.sh --package PATH --output PATH'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$package" ] && [ -f "$package/Package.swift" ] || { echo 'An explicit Swift package path is required.' >&2; exit 2; }
[ -n "$output" ] || { echo 'An explicit output directory is required.' >&2; exit 2; }
[ "$(uname -s)" = Darwin ] || { echo 'Run native macOS tests on macOS.' >&2; exit 2; }
mkdir -p "$output"
# Retain the test exit code through tee. No simulator or screenshot extraction.
swift test --package-path "$package" --xunit-output "$output/results.xml" 2>&1 | tee "$output/tests.log"
