#!/usr/bin/env bash
# Completely removes Susurramelo from this Mac: the app, its data (history, dictionary,
# meetings, API key, preferences) and its privacy permissions.
# Usage: scripts/uninstall.sh [--keep-data]
set -euo pipefail

BUNDLE_ID="com.susurramelo.app"
KEEP_DATA=false
[[ "${1:-}" == "--keep-data" ]] && KEEP_DATA=true

echo "Quitting Susurramelo…"
pkill -x Susurramelo 2>/dev/null || true

for app in "/Applications/Susurramelo.app" "$HOME/Applications/Susurramelo.app"; do
    if [[ -d "$app" ]]; then
        echo "Removing $app"
        rm -rf "$app"
    fi
done

if [[ "$KEEP_DATA" == false ]]; then
    echo "Removing data (history, dictionary, meetings, API key)…"
    rm -rf "$HOME/Library/Application Support/Susurramelo"
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist"
    # API key saved by versions before 0.2.0 lived in the Keychain.
    security delete-generic-password -s com.susurramelo.elevenlabs -a api-key >/dev/null 2>&1 || true
fi

echo "Resetting privacy permissions (Microphone, Accessibility, System Audio Recording)…"
for service in Microphone Accessibility AudioCapture ListenEvent; do
    tccutil reset "$service" "$BUNDLE_ID" >/dev/null 2>&1 || true
done

echo "Done. If Susurramelo was set to launch at login, it was removed together with the app."
