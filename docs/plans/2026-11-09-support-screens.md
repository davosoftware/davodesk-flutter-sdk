# The support screens, the public calls and the example app: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the SDK's native support screens, as approved in `docs/specs/2026-11-09-flutter-sdk-screens.html`; the `DavoDesk` calls an app uses; and the example app that shows them on a phone.

**Architecture:** the screens sit in `lib/src/ui/`. Each page reads one `DavoDeskClient` (plan `2026-11-09-host-api-and-client.md`) through a `SupportScope` InheritedWidget, with the colours resolved from the channel's config and the app's brightness. `DavoDesk` is a static facade that owns the client and pushes full-screen routes on the app's navigator.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Material widgets drawn in our own style, `file_picker`, `url_launcher`, and `flutter_test` widget tests.

**Spec:** `docs/specs/2026-11-09-flutter-sdk-design.md` (§3, §4, §8, §9; approved 2026-11-09). The mockup it approves is `docs/specs/2026-11-09-flutter-sdk-screens.html`.

**Depends on:**
- the plan `2026-11-09-host-api-and-client.md`, merged;
- support-api `2026-11-09-mobile-branding.md`, merged (for the run on the emulator).

## Global Constraints

- **Words, exactly:**
  - **Home:** "Hi {first name} 👋" / "How can we help?" ("Hi there 👋" without a name); "Messages", "Help", "Send us a message"; "Powered by DavoDesk".
  - **Messages:** "No Messages", "Messages from the team will be shown here", "Ask a question".
  - **The chat header:** while the AI answers, "{agent name}" with "The team can also help"; with a person, "{their name}" with "{brand} team · #REF".
  - **Messages in the chat:**
    - the AI's are labelled "{agent name} · AI Agent";
    - "{name} joined" marks when a person joined;
    - a person with no name shows as "{brand} team".
  - **The message box:** "Ask a question…" before a person joins, "Write a message…" after. There is no microphone.
  - **DavoDesk AI's question:** "That solved it" and "Talk to a person".
  - **Notices:** "Reconnecting…" and "Too many messages. Try again in a minute.".
  - **A closed ticket:** "This conversation was closed." and "Start a new conversation".
  - **Email Support:** "Email Support", "Email Us", "Have a question about your order or our services? Our team is here to help.", "Subject", "Message", "OPTIONAL", "Send Email", "Sent. We’ll reply here and by email.", "Added to your open request #REF".
  - **Help:** "Help", "Search help articles", "Was this helpful?".
  - **A ticket:** states Open, Reply, Solved and Closed (grey); "How was the help?" with Good and Bad, as the web widget's rating; "Reopen it" when `reopenable`.
  - **Errors:** "Something went wrong here." and "Start again".
- **References** are `#` plus the ticket id's last six characters, upper-cased (the web's `referenceOf`).
- **Look:**
  - the accent is the channel's `appearance.accent_color`, else `#1d4ed8`, unless `DavoDeskTheme.accent` is given;
  - light or dark follows `Theme.of(context).brightness`. Dark is near-black (`#0b0d12` page, `#14171d` cards);
  - the app's own text theme;
  - cards with 16 px radius;
  - tap targets of at least 48 px;
  - every control has a semantics label.
- **Logos:**
  - the header logo (`headerLogoUrl`) on Home's colour, or the brand name in bold;
  - the square logo (`logoUrl`) on a white tile in chat headers, or the initial;
  - an image that fails to load falls back to its text, never a broken icon;
  - the Powered by mark is a bundled asset, `assets/davodesk_logo.png`, copied from the widget repo.
- **Presentation:** full-screen routes on the app's navigator; the system back goes one page back.
- **Commits** as Hyacinth-Chidi, with no Co-Authored-By trailer. Worktree `../worktrees/davodesk-flutter-screens`, branch `feat/screens`. Merge with `--no-ff`; never push.
- **No writes to the development database** (Task 7's emulator run) without the owner's OK.

## Review Focus

1. **Text at 200 % size** on Home and in the chat: nothing overflows, and long titles end in "…". Test: Task 2 and Task 3, widget tests at `textScaler: TextScaler.linear(2)`.
2. **A conversation waiting for a choice:** the message box is hidden. "Something else", or a free-text step, brings it back. Test: Task 3.
3. **Send tapped twice on the email form:** one ticket, through one idempotency key per tap, and the button disabled while sending. Test: Task 5.
4. **The app's user signs out while support is open:** `logout()` pops the support routes and clears the unread badge. Test: Task 6.
5. **A brand with no published articles:** no Help row and no Help page link. An assistant-only brand has no Messages row. Test: Task 2.

---

### Task 1: The look and the shared pieces

**Files:**
- Create:
  - `lib/src/ui/theme.dart`: `class DavoDeskTheme { final Color? accent; }` and `class SupportColors` (resolved from config, theme and brightness);
  - `lib/src/ui/scope.dart`: `SupportScope` (client, config, colours, email form);
  - `lib/src/ui/widgets/brand_tile.dart`: the square logo or the initial;
  - `lib/src/ui/widgets/header_logo.dart`: the wordmark or the name;
  - `lib/src/ui/widgets/state_chip.dart`;
  - `lib/src/ui/widgets/powered_by.dart`;
  - `lib/src/ui/widgets/recover.dart`: catches a build error and shows "Something went wrong here." with Start again;
  - `lib/src/ui/words.dart`: `referenceOf`, `teamName`, `speakerName`, `firstNameOf`.
- Copy: `assets/davodesk_logo.png` from `../davodesk-widget/src/frame/ui/davodesk-logo.png`, declared in `pubspec.yaml`.
- Test: `test/ui/pieces_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - `referenceOf('6a0000000000009bbc55') == '#9BBC55'`;
  - `teamName('Davopay') == 'Davopay team'`;
  - `firstNameOf('Chukwu Obi') == 'Chukwu'`;
  - `BrandTile` shows the initial when the image errors;
  - `HeaderLogo` shows the name without a URL;
  - `StateChip` labels the six ticket states as the web's `ticket-state.ts`;
  - the accent override beats the channel's.
- [ ] **Step 2: Run** `flutter test test/ui/pieces_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): the look and the shared pieces`.

### Task 2: Home and Messages

**Files:**
- Create: `lib/src/ui/home_page.dart`, `lib/src/ui/messages_page.dart`.
- Test: `test/ui/home_page_test.dart`, `test/ui/messages_page_test.dart`. They use a real `DavoDeskClient` over `MockClient` and a fake socket.

- [ ] **Step 1: Write the failing tests:**
  - **Home:**
    - it greets by first name, or "Hi there 👋";
    - it shows the header logo or the name;
    - its rows are Messages, Help and Send us a message;
    - the links open with `url_launcher`, behind a seam the test fakes;
    - a conversation in progress shows as the top card;
    - Powered by is shown;
    - there is no Help row without articles, and no Messages row for an assistant-only brand;
    - nothing overflows at 200 % text.
  - **Messages:**
    - the list shows subject, who wrote last (with the AI's name), the state, the reference and an unread dot;
    - the empty state's words, and Ask a question opening a conversation;
    - the pencil opens a new conversation;
    - opening a ticket marks it seen.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): Home and Messages`.

### Task 3: The conversation

**Files:**
- Create:
  - `lib/src/ui/conversation_page.dart`;
  - `lib/src/ui/widgets/message_bubble.dart`: the customer's, the AI's with its label and source chips, and a person's;
  - `lib/src/ui/widgets/composer.dart`: the text box, attach (`file_picker`, checked against the API's types and 10 MB before upload), emoji (focuses the system keyboard's emoji), and send.
- Test: `test/ui/conversation_page_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - the header shows the AI's name and "The team can also help"; after `human_joined`, the person's name and "{brand} team · #REF";
  - the tagline, then the notice when it is set;
  - choices are chips; tapping one calls `choose(key)`; the box is hidden while choices wait, and shown after "Something else";
  - "Did this solve it?" offers That solved it and Talk to a person;
  - "Reconnecting…" while reconnecting, and the rate-limit notice;
  - `ended ticket_closed` shows the closed line and Start a new conversation, which calls `startNew()`;
  - a message arriving twice shows once;
  - nothing overflows at 200 % text.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): the conversation`.

### Task 4: A ticket and Help

**Files:**
- Create: `lib/src/ui/ticket_page.dart`, `lib/src/ui/help_page.dart` (search, collections, a collection's articles), `lib/src/ui/article_page.dart`.
- Test: `test/ui/ticket_page_test.dart`, `test/ui/help_page_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - **A ticket:**
    - the state chip;
    - its messages, with names;
    - the rating only when asked: Good or Bad, an optional comment, then Send calls `rate`;
    - Reopen it only when `reopenable`;
    - a closed ticket shows the closed bar;
    - a merged ticket opens the ticket it was merged into.
  - **Help:**
    - search shows hits;
    - collections list their articles;
    - an article shows "Was this helpful?", and a vote calls `vote`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): a ticket and Help`.

### Task 5: Email Support

**Files:**
- Create: `lib/src/ui/email_page.dart`, and in `lib/src/ui/theme.dart`: `class DavoDeskEmailForm { final String? note; final DavoDeskFormField? extraField; }` and `class DavoDeskFormField { final String label; final String? hint; }`.
- Test: `test/ui/email_page_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - the words;
  - the note's card only with a note;
  - the extra field marked OPTIONAL only when set;
  - Send is disabled until Subject and Message are filled;
  - sending calls `raiseTicket` with the extra line, shows "Sent. We’ll reply here and by email.", and opens the ticket;
  - `resumed: true` shows "Added to your open request #REF";
  - a double tap sends once;
  - a refusal shows in place and keeps the text.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): Email Support`.

### Task 6: The `DavoDesk` calls

**Files:**
- Create: `lib/src/davodesk.dart`:

  ```dart
  abstract final class DavoDesk {
    static Future<void> initialize({required String channelId, required Future<String?> Function() identityToken, String apiUrl = 'https://api.davodesk.com', DavoDeskTheme? theme, DavoDeskEmailForm? emailForm});
    static Future<void> show(BuildContext context, {DavoDeskPage page = DavoDeskPage.home});
    static Future<void> ask(BuildContext context, String text);
    static Future<void> openTicket(BuildContext context, String ticketId);
    static ValueListenable<int> get unread;
    static Stream<DavoDeskEvent> get events;
    static Future<void> logout();
  }
  enum DavoDeskPage { home, messages, help, email }
  sealed class DavoDeskEvent {} // DavoDeskOpened, DavoDeskClosed, DavoDeskUnread(count), DavoDeskTicketRaised(id, reference), DavoDeskError(message)
  ```

  Calls made before `initialize` throw a `StateError` with the message "Call DavoDesk.initialize first."
- Modify: `lib/davodesk_flutter.dart`, which exports exactly `DavoDesk`, `DavoDeskPage`, `DavoDeskEvent` and its kinds, `DavoDeskTheme`, `DavoDeskEmailForm`, `DavoDeskFormField`, `DavoDeskClient` and its models. Also `README.md`: setup, the identity function, Android link queries, the iOS photo-library text, and calling the API directly instead.
- Test: `test/davodesk_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - `show` opens Home, and each `page` opens its page;
  - `ask` opens a conversation and sends the text;
  - `openTicket` opens that ticket;
  - the events fire opened and closed, unread, and ticket raised;
  - `logout` pops the support routes, clears unread, and calls the API;
  - a call before `initialize` throws with "Call DavoDesk.initialize first.".
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS and clean. **Commit** `feat(sdk): DavoDesk.initialize, show, ask, openTicket, unread, events and logout`.

### Task 7: The example app, and the screens on a phone

**Files:**
- Modify:
  - `example_app/lib/main.dart`, split into `lib/settings.dart` (the host API address, kept on the device: `http://10.0.2.2:8787` on Android and `http://localhost:8787` on iOS), `lib/sign_in.dart` (Ada or Ben, via `/login`) and `lib/acme_home.dart`:
    - "Hi Ada";
    - Help with the unread badge;
    - Ask about my order;
    - Email us (`page: email`, with `extraField: Order ID` and a note);
    - Sign out;
  - `example_app/pubspec.yaml`: `http`, `shared_preferences`;
  - `example_app/android/app/src/debug/AndroidManifest.xml`: `android:usesCleartextTraffic="true"`, for debug only;
  - the main manifest: `INTERNET`, and the `https` `<queries>` entry `url_launcher` needs.
- Test: `example_app/test/widget_test.dart` (sign in → Acme home, with a fake host API).

- [ ] **Step 1: Write the failing tests:** sign in as Ada shows "Hi Ada" and the Help button; Sign out returns to sign in.
- [ ] **Step 2: Run** `cd example_app && flutter test`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze` and `flutter build apk --debug`. Expected: pass, clean, built. **Commit** `feat(example_app): Acme signs in through the host API and opens support`.
- [ ] **Step 5 (needs the owner's OK; it writes to the development database):**
  1. Run my own API on port 3100, with a test brand, an app channel, a signing key, the name "Callie", a tagline, a notice and a header logo.
  2. Run `host_api` with that channel and key, and `flutter run` the example app on the `pixel1` emulator.
  3. Screenshot every screen in light and dark, and compare them with the approved mockup.
  4. Stop everything I started, and record the outcome in the ledger.
- [ ] **Step 6:** Do the self-review, merge with `--no-ff`, and don't push.
