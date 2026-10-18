#!/usr/bin/env bash
# Builds Susurramelo.app into dist/ (release build, ad-hoc signed).
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/Susurramelo.app"
VERSION="0.1.0"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Susurramelo"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Susurramelo"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.susurramelo.app</string>
    <key>CFBundleName</key><string>Susurramelo</string>
    <key>CFBundleExecutable</key><string>Susurramelo</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.2</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Susurramelo records your voice while you hold the dictation key and sends it to ElevenLabs for transcription.</string>
</dict>
</plist>
PLIST

# macOS ties Keychain access and privacy grants (Accessibility, Microphone) to the code signature.
# A stable identity keeps those grants across rebuilds; ad-hoc signing resets them every build.
# Create the identity once with scripts/create-signing-identity.sh.
IDENTITY="${SIGN_IDENTITY:-Susurramelo Local Signing}"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force --sign "$IDENTITY" --identifier com.susurramelo.app "$APP"
else
    echo "warning: signing identity '$IDENTITY' not found; using ad-hoc signature (permissions reset on every build)" >&2
    codesign --force --sign - --identifier com.susurramelo.app "$APP"
fi
echo "Built $APP"
