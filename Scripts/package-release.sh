#!/bin/zsh
set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PROJECT_DIRECTORY=${SCRIPT_DIRECTORY:h}
: "${DEVELOPER_ID_APPLICATION:?Set the full Developer ID Application identity.}"
: "${NOTARYTOOL_PROFILE:?Set the name of an existing notarytool Keychain profile.}"
DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-SRNLN9U724}
OUTPUT_DIRECTORY="$PROJECT_DIRECTORY/dist"
mkdir -p "$OUTPUT_DIRECTORY"
WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/oled-window-guard-release.XXXXXX")
trap 'rm -rf "$WORK_DIRECTORY"' EXIT

xcodebuild archive -project "$PROJECT_DIRECTORY/OLEDWindowGuard.xcodeproj" \
  -scheme OLEDWindowGuard -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$WORK_DIRECTORY/OLEDWindowGuard.xcarchive" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" OTHER_CODE_SIGN_FLAGS="--timestamp" \
  ENABLE_HARDENED_RUNTIME=YES > "$OUTPUT_DIRECTORY/build-release.log" 2>&1

APP_PATH="$WORK_DIRECTORY/OLEDWindowGuard.xcarchive/Products/Applications/OLED Window Guard.app"
[[ -d "$APP_PATH" ]] || { print -u2 'The archive did not contain the app.'; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
FINAL_ZIP="$OUTPUT_DIRECTORY/OLED-Window-Guard-$VERSION-macOS.zip"
[[ ! -e "$FINAL_ZIP" ]] || { print -u2 "Refusing to overwrite $FINAL_ZIP"; exit 1; }
FINAL_APP_DIRECTORY="$OUTPUT_DIRECTORY/$VERSION"
[[ ! -e "$FINAL_APP_DIRECTORY" ]] || { print -u2 "Refusing to overwrite $FINAL_APP_DIRECTORY"; exit 1; }

[[ $(/usr/libexec/PlistBuddy -c 'Print OLEDUpdateRepository' "$APP_PATH/Contents/Info.plist") == 'baddison2005/oled-window-guard' ]] || { print -u2 'Missing update repository in built app.'; exit 1; }
[[ $(/usr/libexec/PlistBuddy -c 'Print OLEDUpdateChannel' "$APP_PATH/Contents/Info.plist") == 'stable' ]] || { print -u2 'Missing stable update channel in built app.'; exit 1; }

lipo "$APP_PATH/Contents/MacOS/OLED Window Guard" -verify_arch arm64 x86_64
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvvv "$APP_PATH" 2> "$OUTPUT_DIRECTORY/signature.txt"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$WORK_DIRECTORY/submission.zip"
xcrun notarytool submit "$WORK_DIRECTORY/submission.zip" --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait --output-format json > "$OUTPUT_DIRECTORY/notarization.json"
/usr/bin/plutil -extract status raw "$OUTPUT_DIRECTORY/notarization.json" | /usr/bin/grep -qx Accepted
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP"
mkdir -p "$FINAL_APP_DIRECTORY"
ditto "$APP_PATH" "$FINAL_APP_DIRECTORY/OLED Window Guard.app"
shasum -a 256 "$FINAL_ZIP" > "$FINAL_ZIP.sha256"
print "Created signed and notarized app: $FINAL_ZIP"

# Finder presents the application beside an Applications shortcut for drag-install.
FINAL_DMG="$OUTPUT_DIRECTORY/OLED-Window-Guard-$VERSION-macOS.dmg"
[[ ! -e "$FINAL_DMG" ]] || { print -u2 "Refusing to overwrite $FINAL_DMG"; exit 1; }
DMG_CONTENTS="$WORK_DIRECTORY/dmg"
mkdir -p "$DMG_CONTENTS"
ditto "$APP_PATH" "$DMG_CONTENTS/OLED Window Guard.app"
ln -s /Applications "$DMG_CONTENTS/Applications"
cat > "$DMG_CONTENTS/Install.txt" <<'INSTALL'
OLED Window Guard — Stable release

Drag OLED Window Guard.app to Applications, then open it from Applications.
Grant Accessibility access when requested. Select your display and preview
safe moves before starting. The app always launches paused.

Keep your windows moving. Care for your OLED.
Automatically shift and rotate application windows to reduce how long
content stays in one place.

This release is free to use. A future release may be paid.
Movement cannot guarantee prevention of burn-in. Keep your display's OLED
care and sleep features enabled.
INSTALL
hdiutil create -volname 'OLED Window Guard' -srcfolder "$DMG_CONTENTS" -ov -format UDZO "$FINAL_DMG"
codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$FINAL_DMG"
xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait --output-format json > "$OUTPUT_DIRECTORY/notarization-dmg.json"
/usr/bin/plutil -extract status raw "$OUTPUT_DIRECTORY/notarization-dmg.json" | /usr/bin/grep -qx Accepted
xcrun stapler staple "$FINAL_DMG"
xcrun stapler validate "$FINAL_DMG"
hdiutil verify "$FINAL_DMG"
(cd "$OUTPUT_DIRECTORY" && shasum -a 256 "${FINAL_ZIP:t}" "${FINAL_DMG:t}" > "SHA256SUMS-$VERSION.txt")
print "Created signed and notarized disk image: $FINAL_DMG"
