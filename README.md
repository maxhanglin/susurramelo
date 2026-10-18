# Susurramelo

Native macOS menu-bar dictation and meeting notes.

- **Dictate anywhere**: hold **Right Option**, speak, release — the text is typed where your cursor is. Double-tap for hands-free, **Esc** to cancel, **⌃⌘V** pastes your last dictation.
- **Notetaker**: record a meeting from any app (your mic + the call audio) and get a transcript with who said what.
- Personal dictionary, local history, and a floating recording bar.

Transcription uses [ElevenLabs Scribe v2](https://elevenlabs.io/speech-to-text); you bring your own API key.

## Install

Requires a Mac with **Apple Silicon** (M1 or later) and **macOS 14.2+**.

1. Download `Susurramelo-<version>-arm64.zip` from the [latest release](https://github.com/maxhanglin/susurramelo/releases/latest) and unzip it.
2. Move **Susurramelo.app** to your **Applications** folder.
3. Open it. Because the app is not notarized by Apple, macOS blocks the first launch: go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Susurramelo, then confirm. You only do this once.
4. A mic icon appears in the menu bar. Paste your ElevenLabs API key when asked.

Optional: check the download with `shasum -a 256 Susurramelo-<version>-arm64.zip` against the `.sha256` file in the release.

### ElevenLabs API key

Create a key at elevenlabs.io → Developers → API Keys with only these permissions:

| Permission | Access | Why |
|---|---|---|
| Speech to Text | Access | Required — transcribes dictations and meetings |
| User | Access | Optional — lets the app read your credit usage |

The key is saved on your Mac in a file only your user can read, excluded from backups. It is never sent anywhere except ElevenLabs.

### Permissions

macOS asks for each of these once:

| Permission | When | Why |
|---|---|---|
| Microphone | First launch | Hear your dictation and your side of meetings |
| Accessibility | First launch | Detect the dictation key anywhere and paste the text |
| System Audio Recording | First meeting recording | Capture what the other participants say |

## Uninstall

From a clone of this repository:

```bash
scripts/uninstall.sh              # removes the app, your data, the API key and its permissions
scripts/uninstall.sh --keep-data  # keeps history, dictionary, meetings and the key
```

Or manually: quit Susurramelo, delete it from Applications, delete `~/Library/Application Support/Susurramelo`, and remove it from System Settings → Privacy & Security → Microphone / Accessibility / System Audio Recording.

## Build from source

Requires macOS 14.2+ and the Swift 6 toolchain (Xcode Command Line Tools are enough).

```bash
scripts/create-signing-identity.sh   # once per Mac: stable local signing identity
scripts/build-app.sh                 # produces dist/Susurramelo.app
scripts/package-release.sh           # produces dist/Susurramelo-<version>-arm64.zip for a release
swift test                           # unit tests for the core logic
```

The build is signed with a stable local identity, so privacy permissions survive rebuilds. Without it (ad-hoc fallback), macOS treats every build as a new app and asks again.

## Troubleshooting

```bash
/usr/bin/log show --last 5m --info --predicate 'subsystem == "com.susurramelo.app"'
/Applications/Susurramelo.app/Contents/MacOS/Susurramelo --self-test /path/to/16k-mono.wav
/Applications/Susurramelo.app/Contents/MacOS/Susurramelo --usage
```

If paste stops working after switching builds, macOS keeps the old grant and rejects the new signature (`Failed to match existing code requirement` in the TCC log). Quit the app, then:

```bash
tccutil reset Accessibility com.susurramelo.app
```

Relaunch, grant Accessibility again, and relaunch once more.

## How it works

- **Dictation**: hold key → `AVAudioEngine` captures the mic → 16 kHz mono PCM streamed over WebSocket to Scribe v2 Realtime → release commits → the transcript is pasted (Cmd+V) and your clipboard is restored. Taps shorter than 250 ms are ignored.
- **Meetings**: the mic and the system audio (Core Audio process tap) are recorded separately, mixed to mono after the meeting and sent to Scribe v2 with speaker separation. Your own voice is identified by comparing the two channels.

## License

[MIT](LICENSE) © 2026 Max Hanglin
