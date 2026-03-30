#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/artifacts/phase5"
mkdir -p "$OUT_DIR"

echo "[phase5] running swift tests..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test 2>&1 | tee "$OUT_DIR/swift_test.log"

echo "[phase5] building iOS simulator scheme..."
set -o pipefail
xcodebuild \
  -project "$ROOT_DIR/SmartSleepAlarm.xcodeproj" \
  -scheme SmartSleepAlarm-iOS \
  -destination "generic/platform=iOS Simulator" \
  build 2>&1 | tee "$OUT_DIR/ios_sim_build.log"

echo "[phase5] building watchOS simulator scheme..."
xcodebuild \
  -project "$ROOT_DIR/SmartSleepAlarm.xcodeproj" \
  -scheme SmartSleepAlarm-WatchApp \
  -destination "generic/platform=watchOS Simulator" \
  build 2>&1 | tee "$OUT_DIR/watch_sim_build.log"

echo "[phase5] done. logs at $OUT_DIR"
