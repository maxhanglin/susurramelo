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
| T1 | S3 | inline | pending | |
| T2 | S3, S5 | inline | pending | |
| T3 | S2, S4, S6, S8 | inline | pending | |
| T4 | S2, S7 | inline | pending | |
| T5 | S1–S8 | inline | pending | |

- T1: Core `HistoryStore` (add, delete, clear, newest-first, cap, retention purge, stats, JSON round-trip), test-first.
- T2: Record entries after paste; Carbon global hotkey Ctrl+Cmd+V for paste last; menu item with preview.
- T3: Main window shell (sidebar + content), Home with history, Upcoming pages.
- T4: Settings page and persisted preferences (language, launch at login via SMAppService, retention).
- T5: Rebuild, manual check by user, review.

Route evidence: style spec gathered by a read-only explorer (mapping trigger: minified CSS beyond inline budget); writes inline.

## Log

- L1 (2026-10-18, user): see S1 (both messages verbatim).
- L2: Boundary agreed in chat: replicate the look & feel and layout patterns; no copying of logo, illustrations, embedded fonts or texts.
