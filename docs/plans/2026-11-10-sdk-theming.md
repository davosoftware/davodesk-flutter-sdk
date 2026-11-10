# The app's own look (Flutter SDK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** developers make the support screens match their app: the screen colours for light and dark, a heading font beside the body font, and rounded or square corners.

**Architecture:** `DavoDeskTheme` gains `light`/`dark` (`DavoDeskColors`), `headingFontFamily` and `corners` (`DavoDeskCorners`); `SupportColors.resolve` maps them onto the existing tokens and derives the rest; the pieces read the new tokens.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `material_ui`, widget tests.

**Approved:** by the owner in chat, 2026-11-10 ("okay lets do it", on the proposal: colours per mode, heading font, corners, status colours and text size kept, code over the console, a readable accent in dark mode; "remember to add it in documentation for the sdks").

## Global Constraints

- `DavoDeskColors({accent, background, surface, text, border})`: `background` → pages and cards (`paper`), `surface` → fields, the team's bubbles and the space behind Home's cards (`shelf`), `text` → `ink`, with `ink2`/`ink3` derived from it (25 % and 55 % toward `background`), `border` → `rule`. Anything left out keeps DavoDesk's colour. A mode's `accent` beats `DavoDeskTheme.accent`.
- `accentInk`: the accent where it is text, an icon or a dot on the page, made darker (light) or lighter (dark) until it reads at 4.5:1 on `accentSoft`; fills keep the accent.
- `ok`/`warn` and their soft colours stay DavoDesk's; text size follows the phone.
- `headingFontFamily` falls back to `fontFamily`; headings are page titles, the Home greeting, an article's title and an empty state's title.
- `DavoDeskCorners.square`: cards, fields, bubbles, chips, sheets and buttons get square corners; avatars and dots stay round.
- Everything in the earlier SDK plans' Global Constraints still applies (material_ui only, strict analysis, `dart format` before commits); commits as Hyacinth-Chidi, no Co-Authored-By trailer; worktree `../worktrees/davodesk-flutter-theming`, branch `feat/theming`; merge `--no-ff`, never push.

---

### Task 1: Colours for light and dark, and a readable accent

**Files:** `davodesk_flutter/lib/src/ui/theme.dart`, `lib/src/ui/core/support_shell.dart`, the pieces that draw the accent as text, an icon or a dot; `lib/davodesk_flutter.dart` (export `DavoDeskColors`, `DavoDeskCorners`). Test: `test/ui/theme_test.dart`.

- [ ] **Step 1: Failing tests:** a mode's colours map onto `paper`/`shelf`/`ink`/`rule` and derive `ink2`/`ink3`; the other mode keeps DavoDesk's; a mode's accent beats the theme's; `accentInk` reads at 4.5:1 on `accentSoft` for the default blue in dark and for a pale yellow in light, and equals the accent when it already reads; a text button and the Open chip draw in `accentInk`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` and `flutter analyze` → PASS. **Commit** `feat(sdk): the app's colours for light and dark, and an accent that reads`.

### Task 2: A heading font, and square corners

**Files:** `theme.dart`, `support_shell.dart`, `widgets/page_bar.dart`, the Chats bar, Home's greeting, `article_page.dart`, the empty states, and every piece with a corner. Test: `test/ui/theme_test.dart`.

- [ ] **Step 1: Failing tests:** a page title and the Home greeting use `headingFontFamily` while body text uses `fontFamily`; headings fall back to `fontFamily`; with `DavoDeskCorners.square` a Home card, a field, a bubble, the state chip and a filled button have no rounding, and an avatar is still round.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS. **Commit** `feat(sdk): a heading font, and square corners`.

### Task 3: Documentation and the example app

**Files:** `davodesk_flutter/README.md` ("The look"), `README.md` (repo), `example_app/lib/main.dart` (an Acme look behind `--dart-define=ACME_LOOK=true`), `example_app/README` notes if any.

- [ ] **Step 1:** Document every field, what each colour paints, the fallbacks, fonts (bundle the font in the app; Google Fonts works), corners, what stays DavoDesk's, and that code beats the console's accent.
- [ ] **Step 2:** The example app's Acme look; `flutter analyze` and `flutter test` in both folders → PASS. **Commit** `docs(sdk): the app's own look`, self-review, merge `--no-ff`, don't push; check light and dark on the emulator with the Acme look, screenshots.
