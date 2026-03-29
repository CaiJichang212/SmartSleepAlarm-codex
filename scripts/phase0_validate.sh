#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "[Phase0] 1/3 swift test"
xcrun swift test

echo "[Phase0] 2/3 iOS scheme build"
xcodebuild -project SmartSleepAlarm.xcodeproj \
  -scheme SmartSleepAlarm-iOS \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  build >/tmp/smartsleep_phase0_ios.log

echo "[Phase0] 3/3 watchOS scheme build"
xcodebuild -project SmartSleepAlarm.xcodeproj \
  -scheme SmartSleepAlarm-WatchApp \
  -configuration Debug \
  -destination "generic/platform=watchOS Simulator" \
  build >/tmp/smartsleep_phase0_watch.log

echo "[Phase0] all checks passed"
echo "iOS build log: /tmp/smartsleep_phase0_ios.log"
echo "watch build log: /tmp/smartsleep_phase0_watch.log"
