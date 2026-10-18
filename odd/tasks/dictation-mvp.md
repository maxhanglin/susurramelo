# dictation-mvp

Objective: native Swift macOS menu-bar app that dictates into any app: hold a key, speak, release, text gets inserted.
Branch: `feat/dictation-mvp` · Delivery: `ask-on-risk` · Test runner: `swift test` (SwiftPM, CommandLineTools Swift 6.1).

## Specs

- **S1** Platform: "swift nativo, dale vamos con un MVP" — native Swift macOS app, built with SwiftPM (no Xcode project; only CommandLineTools are installed), packaged as a `.app` bundle by a script.
- **S2** Push-to-talk: holding the hotkey starts recording; releasing it stops recording and finalizes the transcript. Default hotkey: Right Option (assumption, configurable later). Presses shorter than ~250 ms are ignored (assumption, avoids accidental taps).
- **S3** Capture: microphone audio converted to 16 kHz mono 16-bit little-endian PCM (matches ElevenLabs `pcm_16000`).
- **S4** Transcription: ElevenLabs Scribe v2 Realtime over WebSocket `wss://api.elevenlabs.io/v1/speech-to-text/realtime?model_id=scribe_v2_realtime&audio_format=pcm_16000&commit_strategy=manual`, header `xi-api-key`. Client sends `{"message_type":"input_audio_chunk","audio_base_64":…,"commit":bool,"sample_rate":16000}`; on release sends a final chunk with `commit: true`. Server messages handled: `session_started`, `partial_transcript`, `committed_transcript`, and error types (`auth_error`, `quota_exceeded`, `input_error`, `invalid_request`, `rate_limited`, `transcriber_error`, `insufficient_audio_activity`, …).
- **S5** Insertion: the committed text is inserted into the focused app by putting it on the pasteboard, simulating Cmd+V, then restoring the previous pasteboard contents.
- **S6** API key: stored in the macOS Keychain, entered from the menu-bar menu. Never written to disk in plain text or committed.
- **S7** Menu bar: status icon reflects idle / recording / transcribing / error; menu offers "Set ElevenLabs API Key…", permission hints, and Quit.
- **S8** Permissions: requests Microphone; detects missing Accessibility permission (needed for the global key monitor and Cmd+V) and tells the user how to grant it.
- **S9** Out of scope for MVP (later phases): LLM formatting, app-context-aware tone, personal dictionary/keyterms UI, history, meeting transcription.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1 | inline | done | d3f65a0, aa09b84 |
| T2 | S3, S4 | inline | done | aa09b84 — RED: types missing; GREEN: 16/16 swift-testing |
| T3 | S2 | inline | done | aa09b84 — PushToTalkTests 5/5 |
| T4 | S3, S4 | inline | done (build only) | a4df5e2 — compiles; runtime unverified |
| T5 | S5, S6, S7, S8 | inline | done (build only) | a4df5e2 — compiles; runtime unverified |
| T6 | S1–S8 | inline | pending | 4971273 bundle; 93dad2b fixes; RDD approved; manual e2e by user still pending (needs their API key, mic, Accessibility) |

- T1: git repo, SwiftPM package (Core library + app executable + tests), `.gitignore`.
- T2: Core: PCM Float32→Int16 conversion/resampling helpers, Scribe message encoding/decoding (test-first).
- T3: Core: push-to-talk state machine with minimum-hold threshold (test-first).
- T4: App: `AVAudioEngine` capture → 16 kHz Int16 chunks; `URLSessionWebSocketTask` Scribe client.
- T5: App: global key monitor, pasteboard insertion, Keychain store, menu-bar UI.
- T6: `scripts/build-app.sh` bundles `Susurramelo.app` (Info.plist with mic usage, ad-hoc signed); manual end-to-end check.

Route evidence: no Writer trigger (no parallel disjoint units launched together, context below backstop) → parent writes inline.

## Log

- L1 (2026-10-18, user): "me gustaría replicar la funcionalidad de dictado completa, incluida la transcripción de reuniones (esta puede esperar), que se te ocurre" → "tengo suscripcion a eleven labs, nos serviría?" → "swift nativo, dale vamos con un MVP"
- L3: ElevenLabs realtime wire format verified from the official elevenlabs-js SDK source (`src/wrapper/realtime/connection.ts`, `scribe.ts`): snake_case fields above; realtime accepts PCM/μ-law only (no Opus).
- L4: XCTest is unavailable with CommandLineTools only; tests use swift-testing (`import Testing`), which works once `platforms` is declared. Package uses tools 6.0 with Swift 5 language mode.
- L5: RDD assess after aa09b84: risk medium, review_due false (under_budget).
- L6: Known limitation: ad-hoc signing means Accessibility grants may need re-adding after each rebuild. A stable self-signed certificate would fix it later.
- L7: Independent verifier on aa09b84..4971273 found one blocker. B1: a new key press during transcription replaced the session and left the mic running. It also reported advisories A1-A10. One correction batch landed in 93dad2b: it fixes B1 (ignores key-down while transcribing, identity-guards the completion, `deinit` cancels the socket), A1 (Right Option device mask 0x40), A2 (clipboard restore skipped if changeCount moved, TransientType), and A7 (`unaccepted_terms`, test RED→GREEN, 16/16). Recheck limited to B1: resolved by diff inspection.
- L8: RDD lineage review-9a32ae151e4e0b7f on target sha256:c44284ed… (HEAD 93dad2b): consent granted by the user; lenses risk/resilience/reliability; approved and acknowledged (gentle-ai.review-acknowledged/v1). The earlier lineage review-10de9661a6c5113f was superseded before consent was applied. The 12 non-blocking advisories are follow-up work: Accessibility granted after launch, early session errors not surfaced while recording, Keychain delete-before-add, ScribeClient lifecycle untested, audio route changes, mic-denied hint, fixed-delay clipboard restore.
- L9 (2026-10-18, user): "no puedo pegar la clave API. Solo me deja escribir, pero no me deja pegar." Cause: an accessory app has no main menu, so Cmd+V has no Edit menu key equivalent. Fix: hidden Edit menu (6db64de).
- L10 (2026-10-18): Logs showed the transcript arrived (42 chars), but the paste failed with `accessibility trusted=false`: the rebuild changed the ad-hoc signature, so the Accessibility grant was lost. Short taps failed with `commit_throttled`, because the server needs at least 0.3 s of uncommitted audio and the mic engine takes about 200 ms to start. Fixes: commit padding (Core, tests 18/18), a clipboard fallback with an error status, unified logging (`/usr/bin/log`, since `log` is a zsh builtin), and `--self-test <wav>`. The self-test transcribed a `say` WAV correctly.
- L11 (2026-10-18, user): "no me gusta que me estés pidiendo la clave de sistema todo el tiempo, y eso está mal. No debería necesitar tantos permisos." Root cause: an unstable ad-hoc signature makes Keychain ACL and TCC grants reset on every rebuild. Proposed fix: a stable self-signed code-signing identity (pending the user's decision).
- L12 (2026-10-18, user): "Sí, creá el certificado de firma estable para que los permisos se pidan una sola vez." Created a self-signed identity "Susurramelo Local Signing" (login keychain, -T codesign, untrusted, which is fine). build-app.sh uses it, with ad-hoc fallback. Designated requirement = identifier + certificate leaf H"7490816d…", verified identical across two rebuilds (ff2f98d). One-time re-grant needed: Keychain "Always Allow" and re-adding Accessibility.
