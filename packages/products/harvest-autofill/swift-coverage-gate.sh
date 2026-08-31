#!/bin/bash
# Runs the HarvestCore Swift test suite with coverage and fails if line coverage of
# HarvestCore.swift is below the floor. The subprocess/launchctl/install side effects live
# in HarvestSideEffects.swift (excluded from this library target) and are covered by the
# app's E2E render/self-test hooks + visual regression instead.
set -euo pipefail
cd "$(dirname "$0")"
FLOOR="${SWIFT_COV_FLOOR:-75}"

# A full Xcode is needed for the macOS SDK the app uses.
if [ -z "${DEVELOPER_DIR:-}" ]; then
  XC="$(find /Applications -maxdepth 1 -name 'Xcode*.app' | head -1)"
  if [ -n "$XC" ]; then
    DEVELOPER_DIR="$XC/Contents/Developer"
    export DEVELOPER_DIR
  fi
fi
HARVEST_DATA_DIR="$(mktemp -d)"
export HARVEST_DATA_DIR

swift test --enable-code-coverage

XCTEST="$(find .build -name 'HarvestCorePackageTests.xctest' -type d | head -1)"
PROF="$(find .build -name 'default.profdata' | head -1)"
BIN="$XCTEST/Contents/MacOS/HarvestCorePackageTests"

PCT="$(xcrun llvm-cov report "$BIN" -instr-profile "$PROF" 2>/dev/null |
  awk '/HarvestCore.swift/ {gsub(/%/,"",$10); print $10}')"

echo "HarvestCore.swift line coverage: ${PCT}% (floor ${FLOOR}%)"
awk -v p="$PCT" -v f="$FLOOR" 'BEGIN { exit !(p+0 >= f+0) }' ||
  {
    echo "FAIL: Swift logic coverage ${PCT}% is below ${FLOOR}%"
    exit 1
  }
echo "Swift coverage gate passed."
