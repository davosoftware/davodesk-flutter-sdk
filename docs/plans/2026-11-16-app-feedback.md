# App feedback (Flutter SDK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The SDK side of the app feedback: a sent message shows at once with Retry, typing dots, a chat that refreshes and keeps its newest line in view, gentle motion, the contact form's intro and outcome, the chats list avatar, and two fixes (Start a new chat; the sheet and toolbar in framework-Material apps).

**Architecture:** The chat repository sends `client_id`, hears `typing` and asks `session:sync`. The domain's `Conversation` gains pending messages and a typing state; the conversation view model turns them into bubbles. The pages change only where they show them.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `material_ui`, `flutter_test`.

**Spec:** `docs/specs/2026-11-16-app-feedback-design.md` (copied from davodesk-apps).

## Global Constraints

- No new dependencies and no new permissions: nothing for voice.
- Works with the API before and after its part of this change: `client_id`, `typing` and `session:sync` are optional.
- The domain imports no UI. Copy in British English, as the SDK's.
- Floor stays Flutter 3.47 / Dart 3.13.
- Commits under the owner's identity, no Co-Authored-By trailer.

## Review Focus

1. A socket that drops between send and echo: the snapshot after reconnecting replaces the "Sending…" bubble. Pinned in Task 2.
2. Two identical messages sent quickly each find their own echo. Pinned in Task 2.
3. The typing bubble never sticks: a message from that party, `typing: false`, 8 s, or the chat ending clears it. Pinned in Task 3.
4. A long chat: the newest line, the typing bubble included, is in view after each arrival. Pinned in Task 5.
5. An app on Flutter's own Material: the attachment sheet and the text toolbar open without errors. Pinned in Task 9.

---

### Task 1: The chat's new events and calls

**Files:**
- Modify: `lib/src/data/repositories/chat_repository.dart` (`send(content, {clientId})` sends `client_id`; `typing` → `TypingEvent`; `sync()` emits `session:sync`), `lib/src/domain/chat_events.dart` (`TypingEvent(by, typing, name)`), `lib/src/domain/models.dart` (`ChatMessage.clientId` from `client_id`)
- Test: `test/data/` (the chat repository's test), `test/domain/models_test.dart`

- [ ] **Step 1: Failing tests:** sends carry `client_id`; a `typing` event becomes `TypingEvent(by: TypingBy.ai, typing: true)`; `sync()` emits `session:sync` once admitted; `client_id` is read, absent → null.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: the chat sends client ids, hears typing and can ask for a snapshot`

### Task 2: A sent message shows at once

**Files:**
- Modify: `lib/src/domain/conversation.dart` (`Conversation.pending: List<PendingMessage>`; `SendStarted(clientId, content)`, `SendFailed(clientId)`; an echo replaces its pending message by `clientId`, else the oldest with the same text; a snapshot drops pending messages whose text it holds), `lib/src/client.dart` (`send` makes the id, reduces `SendStarted`, marks `SendFailed` on `ok: false`; `retry(clientId)`), `conversation_view_model.dart` (pending → `BubbleItem` with `status: sending | failed` and `clientId`), `widgets/message_bubble.dart` ("Sending…", "Not sent · Retry")
- Test: `test/domain/conversation_test.dart`, `test/ui/conversation_page_test.dart`

- [ ] **Step 1: Failing tests** `test('an echo replaces its own pending message')`, `test('two identical messages each find their own echo')`, `test('a snapshot after a reconnect replaces the pending message')`, `testWidgets('a message shows at once as Sending…, then as sent')`, `testWidgets('a refused send offers Retry, which sends it again')`.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: a sent message shows at once, with Retry when it fails`

### Task 3: Typing dots

**Files:**
- Modify: `conversation.dart` (`Conversation.typing`: by, name, since; cleared by a message from that party, `typing: false`, and the chat ending), `conversation_view_model.dart` (a `TypingItem`; an 8 s timer clears a stale one), a new `lib/src/ui/widgets/typing_bubble.dart` (DavoDesk AI: the run head with `BrandTile` and the bot's name; the team: the name; three dots, still when animations are off)
- Test: `test/ui/pieces_test.dart`, `test/ui/conversation_page_test.dart`

- [ ] **Step 1: Failing tests** `testWidgets('DavoDesk AI typing shows under its head and goes with its answer')`, `testWidgets("the team's typing shows the member's name and goes after 8 seconds")`.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: typing dots for DavoDesk AI and the team`

### Task 4: The chat refreshes

**Files:**
- Modify: `lib/src/client.dart` (`sync()`; `resumed()` also syncs), `conversation_view_model.dart` (`load` syncs a chat already connected; `refresh()`), `conversation_page.dart` (`RefreshIndicator` on the list)
- Test: `test/ui/conversation_page_test.dart`, `test/client_test.dart`

- [ ] **Step 1: Failing tests** `testWidgets('pulling the chat down asks for a fresh snapshot')`, `testWidgets('opening the chat again asks for a fresh snapshot')`, `test('coming back to the app asks for a fresh snapshot')`.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: the chat refreshes on open, on return and on pull`

### Task 5: The newest line stays in view, and new bubbles slide in

**Files:**
- Modify: `conversation_page.dart` (the list `reverse: true`, lines in reverse; a line that arrives after the first build fades and rises 8 px over 180 ms, none under `MediaQuery.disableAnimations`)
- Test: `test/ui/conversation_page_test.dart`

- [ ] **Step 1: Failing tests** `testWidgets('in a long chat, a new line is in view')`, `testWidgets('a new bubble slides in, unless the phone asks for less motion')`.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: the chat keeps its newest line in view, and new bubbles slide in`

### Task 6: The contact form's intro and outcome

**Files:**
- Modify: `lib/src/ui/theme.dart` (`DavoDeskContactForm.intro`), `contact_page.dart` (default "Have a question? Our team is here to help."; passes the outcome), `lib/src/ui/core/scope.dart` (`TicketPlace(id, {notice})`), `davodesk.dart` (`_pageOf`), `ticket_page.dart` (a banner at the top when `notice` is set)
- Test: `test/ui/contact_page_test.dart`, `test/ui/ticket_page_test.dart`, `test/davodesk_test.dart`

- [ ] **Step 1: Failing tests** `testWidgets("the intro is neutral, or the app's own")`, `testWidgets('after sending, the request opens saying where the message went')` (joined: "Added to your open request #8DEE9D"; new: "Sent. We'll reply here.").
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: the contact form's intro is the app's, and says where a message went`

### Task 7: The chats list shows the brand

**Files:**
- Modify: `lib/src/ui/features/messages/messages_view_model.dart` and its page (a team member's initial when one wrote last; else `BrandTile`)
- Test: `test/ui/messages_page_test.dart`

- [ ] **Step 1: Failing test** `testWidgets("a row shows the brand's tile, not the customer's own initial")`.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `feat: the chats list shows the brand, or the team member who answered`

### Task 8: Start a new chat raises no assertion

**Files:**
- Modify: `conversation_page.dart` (the first `load()` after the first frame)
- Test: `test/davodesk_test.dart`

- [ ] **Step 1: Failing test** `testWidgets('Start a new chat from Chats while Home is open raises no assertion')` (`tester.takeException()` is null).
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `fix: Start a new chat no longer rebuilds Home during a build`

### Task 9: The sheet and the toolbar in apps on Flutter's own Material

**Files:**
- Modify: `lib/src/ui/widgets/composer.dart` (the attachment sheet's content wrapped in the SDK's localizations and theme), the SDK's `TextField`s (a `contextMenuBuilder` wrapping the toolbar the same way), a small helper in `lib/src/ui/core/support_shell.dart`
- Test: `test/davodesk_test.dart` (an app on `flutter/material.dart`)

- [ ] **Step 1: Failing tests** `testWidgets('the attachment sheet opens in an app on Flutter Material')`, `testWidgets('the text toolbar opens in an app on Flutter Material')`.
- [ ] **Step 2–4:** fail, implement, pass. **Commit** `fix: the attachment sheet and the text toolbar work in apps on Flutter Material`

### Task 10: README and CHANGELOG

- [ ] README: `intro`; sending, typing and refresh need nothing from the app; the localizations workaround is no longer needed. CHANGELOG entry. **Commit** `docs: what the app feedback changed`

### Task 11: Prove it on the emulator

- [ ] **With the owner's OK,** against a local API with davodesk-apps' plan merged: sending, Retry, typing (AI and team), refresh, the subject rule, the avatar. Screenshots into a fresh `screens-app-feedback`.
