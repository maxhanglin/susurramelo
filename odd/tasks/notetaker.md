# notetaker

Objective: record meetings (mic + system audio), transcribe them after the meeting with ElevenLabs Scribe v2 batch with speaker separation, and browse them in a Notetaker page.
Branch: `feat/notetaker` (from `main`) · Delivery: `ask-on-risk` · Test runner: `swift test` (swift-testing).

## Specs

- **S1** User request/approval (verbatim): "me interesa más hacer lo del notetaker primero" · scope approval "perfecto, me sirve" · provider "Con ese costo vamos con ElevenLabs para el Notetaker, reusando la integración."
- **S2** Recording: start/stop from the Notetaker page and from the menu-bar menu. Captures the microphone and the system audio (all apps) at the same time. Uses the macOS system-audio capture API (Core Audio process tap, macOS 14.2+), which asks once for "System Audio Recording" permission.
- **S3** Storage: audio saved locally in Application Support as a compressed stereo file (mic = left channel, system audio = right channel); metadata and transcript as JSON next to it.
- **S4** Transcription: when recording stops, a mono mixdown of the recording is sent to ElevenLabs Scribe v2 batch (`POST /v1/speech-to-text`, `model_id=scribe_v2`, `diarize=true`, word timestamps). The result has words with `speaker_id` and timestamps. (Decided by T1 spike, see L3.)
- **S5** Transcript view: consecutive words of the same speaker are grouped into turns with start time; speakers show as "Speaker 1, 2…" and can be renamed; names persist. The speaker whose turns are dominated by the local mic channel (left) is labelled "Me" automatically (energy comparison of left vs right channel over the speaker's word time ranges).
- **S6** Notetaker page (no longer "Upcoming"): list of meetings (title editable, date, duration, status: recording / transcribing / done / failed with retry), detail with transcript, copy, export to Markdown, delete (audio + transcript).
- **S7** Out of scope (later): live transcript during the meeting, AI summary/action items, calendar integration, automatic meeting detection.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S4 | inline | done | live API test, see L3 |
| T2 | S3, S5, S6 | inline | done | 2d9da93 + EnergyTrack — RED→GREEN 71/71 |
| T3 | S4 | inline | done | ce0bd18 BatchTranscriber (multipart streamed from disk) |
| T4 | S2, S3 | inline | partial | recorder written (mic AAC + Core Audio process tap); post-processing verified with --meeting-test on simulated meeting (me detected, 6 turns correct); live capture untested (needs System Audio Recording permission) |
| T5 | S2, S5, S6 | inline | pending | |
| T6 | S1–S6 | inline | pending | |

- T1: Spike — verify the batch API contract from the official SDK and run a live test with a 2-voice stereo file (diarize vs multichannel vs both); measure credits with `--usage`.
- T2: Core `Meeting` model, `TranscriptTurns` builder from words, speaker naming, Markdown export, persistence (test-first).
- T3: Batch client: multipart upload, response decoding (decoder test-first), error handling.
- T4: `MeetingRecorder`: AVAudioEngine mic + Core Audio process tap → stereo AAC file; Info.plist `NSAudioCaptureUsageDescription`.
- T5: Notetaker UI (list, detail, rename speakers, export) + menu-bar start/stop + recording indicator.
- T6: Rebuild, live check by the user with a real call, RDD review (new permission + uploads private audio → likely high risk).

Route evidence: T3 and T4 are independent but each lighter than spinning a writer; parent writes inline.

## Log

- L1 (2026-10-18, user): see S1.
- L2: Prior research (Engram): diarization only in batch (`diarize`, `num_speakers` ≤32, `diarization_threshold`); multichannel `use_multi_channel` (≤5 channels, billed per channel); docs conflict on multichannel max duration (1 h vs 10 h); unknown whether diarize + multichannel combine. Measured realtime cost ~30 credits/min; batch should be cheaper (USD $0.22/h vs $0.39/h).
- L3 (T1 spike, 2026-10-18): Simulated 28.8 s meeting (me=Paulina left; Eddy + Mónica right). Results — mono mix + `diarize=true`: 3 speakers / 6 turns all correct, 1.4 s latency. `use_multi_channel` (combined): merges both remote voices into one speaker (labels by channel only). `use_multi_channel` + `diarize`: HTTP 400 "Multichannel mode does not support diarization". Decision: record stereo locally, upload mono mixdown with diarize (1× cost), detect "Me" locally by channel energy.
- L4: Design refinement: record `mic.m4a` + `system.m4a` (AAC) during the meeting; afterwards stream-mix to 16 kHz mono `audio.m4a` and store 100 ms RMS energy tracks (`energy.json`) — no large stereo file. Minimum macOS raised to 14.2 for `AudioHardwareCreateProcessTap`.
- L5: `--meeting-test` on simulated meeting: me=speaker_0, transcript 6 turns correct with names Me / Speaker 2 / Speaker 3.
- L6 (2026-10-18, user): "lo de la key chain..." → "dale, hacelo así, no voy a pagar una cuenta de desarrollador de apple" / "ponele un nombre en clave que nadie sepa que ahi adentro hay una api key" / "y obviamente en gitignore". Keychain "Always Allow" proved bound to each build even with the self-signed cert trusted for codeSign (fire test: 0.2.0 rebuild blocked 20 s on a prompt). API key moved to Core `APIKeyFile` (0600 file in 0700 folder, created with O_CREAT 0600, excluded from backup; tests 6) at an innocuous path; one-time migration from the legacy Keychain item, which is then deleted. Verified: migration log line, `-rw-------`, `drwx------`, backup exclusion set, `--usage` reads in 2 s with no prompt. .gitignore gains generic secret patterns (file lives outside the repo, its name intentionally not listed).
