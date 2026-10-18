# Susurramelo

Native macOS menu-bar dictation: hold **Right Option**, speak, release — the text is typed into whatever app has focus. Transcription uses [ElevenLabs Scribe v2 Realtime](https://elevenlabs.io/realtime-speech-to-text).

## Build

Requires macOS 14.2+ and the Swift 6 toolchain (Xcode Command Line Tools are enough).

```bash
scripts/create-signing-identity.sh   # once per Mac: stable local signing identity
scripts/build-app.sh                 # produces dist/Susurramelo.app
swift test             # unit tests for the core logic
```

## First run

1. `open dist/Susurramelo.app` — a mic icon appears in the menu bar.
2. Paste your ElevenLabs API key when asked (stored in the Keychain; change it later from the menu).
3. Allow **Microphone** access.
4. Allow **Accessibility** in System Settings → Privacy & Security → Accessibility. It is needed to paste into other apps.

The build is signed with a stable local identity, so these permissions are asked once and survive rebuilds. Without it (ad-hoc fallback), macOS treats every build as a new app and asks again.

## Troubleshooting

```bash
/usr/bin/log show --last 5m --info --predicate 'subsystem == "com.susurramelo.app"'
dist/Susurramelo.app/Contents/MacOS/Susurramelo --self-test /path/to/16k-mono.wav
```

If paste stops working after switching signing (e.g. from an ad-hoc build), macOS keeps the old grant and rejects the new signature (`Failed to match existing code requirement` in the TCC log). Quit the app, then:

```bash
tccutil reset Accessibility com.susurramelo.app
```

Relaunch, grant Accessibility again, and relaunch once more.

## How it works

Hold key → `AVAudioEngine` captures the mic → 16 kHz mono Int16 PCM → streamed over WebSocket to Scribe → release sends `commit: true` → the committed transcript is pasted (Cmd+V) and your clipboard is restored.

Taps shorter than 250 ms are ignored.

## License

[MIT](LICENSE) © 2026 Max Hanglin
