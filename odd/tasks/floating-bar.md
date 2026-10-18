# floating-bar

Objective: floating recording bar with a live voice waveform, Esc to cancel, and a hands-free (locked) dictation mode.
Branch: `feat/floating-bar` (from `feat/dictation-mvp`) · Delivery: `ask-on-risk` · Test runner: `swift test` (swift-testing).

## Specs

- **S1** User request (verbatim): "Arranquemos por la barra flotante de grabación con onda de voz, Esc para cancelar y modo manos libres."
- **S2** Floating bar: a small pill shown at the bottom center of the active screen (above the Dock) while dictating; hidden when idle. It never takes focus from the app being typed into, stays above full-screen apps and on all Spaces, and lets clicks pass through. Own design (no reference assets).
- **S3** Waveform: the bar shows bars that react in real time to the microphone level while recording.
- **S4** Bar states: recording (waveform), hands-free (waveform + lock indicator), transcribing (progress animation), error (short message, then hides after a few seconds).
- **S5** Esc cancels: pressing Esc while recording, hands-free or transcribing discards the dictation; nothing is pasted and the bar hides.
- **S6** Hands-free (assumption: double-tap Right Option): a quick tap followed by a second press within ~0.4 s locks recording without holding the key; pressing Right Option again finishes and pastes. Audio captured from the first press is kept.
- **S7** Existing behavior preserved: hold ≥ 0.25 s and release commits; a single short tap with no second press cancels.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S5, S6, S7 | inline | done | 9b69bab — RED: types missing; GREEN 33/33 (DictationGestureTests 15) |
| T2 | S3 | inline | done | 9b69bab — AudioLevelTests 5/5 |
| T3 | S2, S3, S4 | inline | done | f4636cc — confirmed visually by user |
| T4 | S2–S7 | inline | done | user e2e 2026-10-18: logs show 7 recordings, 4 hands-free, 4 transcribed+pasted, 3 cancelled |

- T1: Core `DictationGesture` state machine replacing `PushToTalk` (hold, double-tap lock, Esc, tap timeout), test-first.
- T2: Core `AudioLevel` (RMS → 0…1 on a dB scale) and a rolling bar history, test-first.
- T3: App `FloatingBar` NSPanel + SwiftUI view for each state.
- T4: Wire capture levels, the Esc key monitor, hands-free and the bar into `DictationController`; rebuild; manual check by the user.

Route evidence: no Writer trigger (units share `DictationController`; context below backstop) → inline.

## Log

- L1 (2026-10-18, user): "Arranquemos por la barra flotante de grabación con onda de voz, Esc para cancelar y modo manos libres."
- L3: Known limitation: an NSEvent global monitor cannot swallow Esc, so the frontmost app also receives it. Acceptable for now; a CGEventTap could consume it later.
- L4: RDD assess b09bd02..f4636cc: medium, under_budget (no review due yet).
- L5 (2026-10-18, user): "Sí, ahora parece que funciona también el modo manos libres. Y el \"escape\" también funciona perfecto." All tasks done.
