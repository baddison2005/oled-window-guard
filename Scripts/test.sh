#!/bin/zsh
set -euo pipefail
SCRIPT_DIRECTORY=${0:A:h}
PROJECT_DIRECTORY=${SCRIPT_DIRECTORY:h}
xcodebuild test -project "$PROJECT_DIRECTORY/OLEDWindowGuard.xcodeproj" \
  -scheme OLEDWindowGuard -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$PROJECT_DIRECTORY/build" CODE_SIGNING_ALLOWED=NO
