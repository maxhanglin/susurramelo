# dictionary

Objective: personal dictionary — custom words that bias transcription (Scribe keyterms) and replacement rules applied to the final text — with a Dictionary page in the main window.
Branch: `feat/dictionary` (from `feat/hub-history`) · Delivery: `ask-on-risk` · Test runner: `swift test` (swift-testing).

## Specs

- **S1** User approval (verbatim): "si dale" — to the proposal: personal dictionary with up to 50 keyterms sent to ElevenLabs plus automatic replacements ("if it hears X, write Y"), as a new page in the main window with the same list/search/add/delete design.
- **S2** Words: the user adds words or short phrases. Each word of at most 20 characters is sent to Scribe as a keyterm (repeated `keyterms` query parameter); at most 50 are sent (most recent first). Longer words are kept but not sent, and the UI says so.
- **S3** Replacements: an entry can optionally replace a misspelling: when the transcript contains the "heard as" text (case-insensitive, whole words), it is replaced with the word before pasting and saving to history.
- **S4** Page: "Dictionary" in the sidebar under Home; search, add (word + optional "replace a misspelling" field), delete, counter "n / 50 words sent", empty state, and a note that keyterms add about 20% to transcription cost.
- **S5** Persistence: stored locally as JSON in Application Support (`dictionary.json`); duplicates (case-insensitive) are rejected.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S2, S3, S5 | inline | done | 24df6c3 — RED→GREEN 55/55 (UserDictionaryTests 11, incl. '+' encoding) |
| T2 | S2, S3 | inline | done | 1f4f082 — self-test with keyterms: 'Susurrámelo' → 'Susurramelo' |
| T3 | S4 | inline | done | 1f4f082 — snapshot renders light/dark |
| T4 | S1–S5 | inline | pending | app rebuilt + relaunched; awaiting user check |

- T1: Core `UserDictionary` (validation, keyterms selection, replacements, persistence) and `ScribeProtocol.realtimeURL(..., keyterms:)`, test-first.
- T2: Load the dictionary in the app; send keyterms on connect; apply replacements to the transcript.
- T3: Dictionary page (SwiftUI, existing theme).
- T4: Rebuild, self-test with keyterms against ElevenLabs, user check.

## Log

- L1 (2026-10-18, user): "si dale"
- L2: Verified in elevenlabs-js `src/wrapper/realtime/scribe.ts`: keyterms are appended as repeated `keyterms` query params; max 50, each ≤ 20 chars. Pricing page (researched earlier): keyterms +20%.
- L3: Found while testing: URLComponents leaves '+' unescaped (server would read a space); fixed with %2B and a test.
- L4: Live self-test against ElevenLabs with keyterms [Susurramelo, C++, ElevenLabs]: accepted; transcript changed from 'Susurrámelo' (no keyterms) to 'Susurramelo'.
