#!/usr/bin/env bash
# Builds Susurramelo.app into dist/ (release build, ad-hoc signed).
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/Susurramelo.app"
VERSION="0.1.0"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Susurramelo"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Susurramelo"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.susurramelo.app</string>
    <key>CFBundleName</key><string>Susurramelo</string>
    <key>CFBundleExecutable</key><string>Susurramelo</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Susurramelo records your voice while you hold the dictation key and sends it to ElevenLabs for transcription.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: macOS ties Accessibility/Microphone grants to it, so each rebuild may
# require re-granting Accessibility (remove and re-add the app in System Settings).
codesign --force --sign - --identifier com.susurramelo.app "$APP"
echo "Built $APP"
