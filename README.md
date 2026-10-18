# Susurramelo

Native macOS menu-bar dictation: hold **Right Option**, speak, release — the text is typed into whatever app has focus. Transcription uses [ElevenLabs Scribe v2 Realtime](https://elevenlabs.io/realtime-speech-to-text).

## Build

Requires macOS 14+ and the Swift 6 toolchain (Xcode Command Line Tools are enough).

```bash
scripts/build-app.sh   # produces dist/Susurramelo.app
swift test             # unit tests for the core logic
```

## First run

1. `open dist/Susurramelo.app` — a mic icon appears in the menu bar.
2. Paste your ElevenLabs API key when asked (stored in the Keychain; change it later from the menu).
3. Allow **Microphone** access.
4. Allow **Accessibility** in System Settings → Privacy & Security → Accessibility. It is needed to detect the key globally and to paste. After a rebuild you may need to remove and re-add the app there (ad-hoc signature).

## How it works

Hold key → `AVAudioEngine` captures the mic → 16 kHz mono Int16 PCM → streamed over WebSocket to Scribe → release sends `commit: true` → the committed transcript is pasted (Cmd+V) and your clipboard is restored.

Taps shorter than 250 ms are ignored.
