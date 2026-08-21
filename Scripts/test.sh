#!/bin/bash
#
# test.sh — run BookGate's test suite the way CI does.
#
#   Scripts/test.sh                       # default simulator
#   DEVICE="iPhone 17 Pro" Scripts/test.sh
#
# Two flags are not optional:
#   -parallel-testing-enabled NO   SKTestSession mutates process-global state.
#   -test-timeouts-enabled YES     honours each case's executionTimeAllowance, so a StoreKit
#                                  call that raises a system dialog fails in a minute instead
#                                  of stalling the run for ten.
set -euo pipefail

if [ -z "${DEVELOPER_DIR:-}" ] && ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  [ -d /Applications/Xcode.app ] && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

DEVICE="${DEVICE:-iPhone 17 Pro Max}"
UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
[ -n "$UDID" ] || { echo "Simulator '$DEVICE' not found."; exit 1; }

xcodebuild test \
  -project BookGate.xcodeproj \
  -scheme BookGate \
  -destination "platform=iOS Simulator,id=$UDID" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 60 \
  "$@"
