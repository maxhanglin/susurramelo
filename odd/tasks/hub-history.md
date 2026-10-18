# hub-history

Objective: main app window in the reference app's visual style (own brand) with Home/history, Settings, and "Upcoming" Insights and Notetaker pages; local dictation history with a paste-last shortcut.
Branch: `feat/hub-history` (from `feat/floating-bar`) · Delivery: `ask-on-risk` · Test runner: `swift test` (swift-testing).

## Specs

- **S1** User request (verbatim): "dale, seguimos por ahí, pero me gustaría que elabores el frontend con el mismo estilo que una aplicación de dictado comercial. Me gusta la UI que tiene. Quiero además la parte de insights y notetaker como \"upcoming\"" and "la parte de settings que tiene esta buena también".
- **S2** Style: same general look & feel as the reference hub (sidebar layout, palette, radii, spacing, typography feel) from an abstract style spec; our own brand (icon, gradient accent, SF Symbols, own copy). No reference assets, fonts, logos or verbatim text.
- **S3** Local history: every successful dictation is stored locally (text, date, duration, word count, frontmost app name). Stored in Application Support as JSON, newest first, capped at 1000 entries. Retention setting: keep / delete after 24 h / never store.
- **S4** Home page: greeting and simple stats from history (total words, dictations), history grouped by day with time, text, and actions copy and delete; search; empty state.
- **S5** Paste last transcript: global shortcut Ctrl+Cmd+V pastes the most recent entry; the menu-bar menu shows "Paste last transcript" with a one-line preview.
- **S6** Insights and Notetaker appear in the sidebar with an "Upcoming" badge and a placeholder page describing what is coming.
- **S7** Settings page: ElevenLabs API key (set/replace, masked), dictation language (auto or fixed), launch at login, history retention + clear history, permissions status (microphone, accessibility) with buttons to fix, shortcuts shown read-only. Microphone picker shown as "Upcoming".
- **S8** Window: opened from the menu-bar menu ("Open Susurramelo"); the app stays a menu-bar app (no Dock icon unless the window is open — assumption).

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S3 | inline | done | 050e271 — RED: types missing; GREEN 44/44 (HistoryTests 11) |
| T2 | S3, S5 | inline | done (build only) | e26228e — Carbon hotkey ⌃⌘V, menu preview |
| T3 | S2, S4, S6, S8 | inline | done | ce17d16 — verified via --snapshot renders (light/dark, all pages) |
| T4 | S2, S7 | inline | done | ce17d16 — verified via --snapshot renders |
| T5 | S1–S8 | inline | pending | app rebuilt (stable signature) and relaunched; awaiting user check |

- T1: Core `HistoryStore` (add, delete, clear, newest-first, cap, retention purge, stats, JSON round-trip), test-first.
- T2: Record entries after paste; Carbon global hotkey Ctrl+Cmd+V for paste last; menu item with preview.
- T3: Main window shell (sidebar + content), Home with history, Upcoming pages.
- T4: Settings page and persisted preferences (language, launch at login via SMAppService, retention).
- T5: Rebuild, manual check by user, review.

Route evidence: style spec gathered by a read-only explorer (mapping trigger: minified CSS beyond inline budget); writes inline.

## Log

- L1 (2026-10-18, user): see S1 (both messages verbatim).
- L2: Boundary agreed in chat: replicate the look & feel and layout patterns; no copying of logo, illustrations, embedded fonts or texts.
- L3: Style spec from explorer: warm paper palette (#F5F4F0 canvas, #FCFCFB panel, #EEEBE3 fill/border, #1A1A1A ink), 24/16 radius floating panel, 6 px nav radius with fill selection, serif stat numbers, day-grouped history with 98 pt time column and hover actions. Mapped to SF Pro + New York serif + own brand gradient (no reference fonts/assets).
- L4: Added `--snapshot <dir>` (renders all pages light/dark with sample data in a temp file) for visual QA. Fixed: logo now a code-drawn BrandMark; sidebar 236 pt; badge shrunk so "Upcoming" fits.
- L5: RDD assess 448ef37..ce17d16: medium, under_budget.
- L6 (2026-10-18, user, mid-task): "investiga si elevenlabs puede reconocer diferentes voces en una grabación, nos serviría mucho para la parte de notetaking" → answered: diarization batch-only (Scribe v2 `diarize`, up to 32 speakers; multichannel option), not realtime. Saved in Engram for the notetaker feature.
