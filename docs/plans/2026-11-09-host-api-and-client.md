# The host API and the SDK's client: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:**
- `host_api` signs identity tokens for the pretend customers;
- `davodesk_flutter` gets the client the screens will stand on: API calls, the session, live chat, the conversation's state, unread markers, and raising a ticket.

**Architecture:** a Dart port of the web widget's frame logic. Each part follows the web code it names:
- `api/client.ts` → `api.dart`;
- `session/session.ts` → `session.dart`;
- `chat/connection.ts` → `chat.dart`;
- `chat/conversation.ts` → `conversation.dart`;
- `unread.ts` → `unread.dart`.

Socket.IO sits behind a small `ChatSocket` interface, so tests use a fake. `DavoDeskClient` puts them together for the screens and for apps that draw their own.

**Tech Stack:**
- the SDK: Dart 3.13 and Flutter 3.47, with `http`, `socket_io_client` (Socket.IO v4) and `shared_preferences`, and `fake_async` for tests;
- host_api: `shelf`, `shelf_router` and `crypto`.

**Spec:** `docs/specs/2026-11-09-flutter-sdk-design.md` (§3, §6, §7; approved 2026-11-09).

**Depends on:** the support-api plan `2026-11-09-mobile-branding.md`, merged into its `main`. The client reads the config's new fields.

## Global Constraints

- **Signed-in customers only** (app channels have no visitors): no visitor token, no email request, no `host_origin`, no `Origin` header.
- **Session rules** (guide §2 and §4):
  - the token is in memory only;
  - renew 60 s before `expires_in` runs out;
  - backoff `min(300000, 1000 × 2^attempt) × (0.5 + random / 2)` ms;
  - `429` waits for `Retry-After`;
  - the identity function returning null or throwing is `TOKEN_FAILED` and retries;
  - `INVALID_IDENTITY_TOKEN` and `IDENTITY_EMAIL_CONFLICT` are `TOKEN_FAILED`;
  - anything else is `CHANNEL_UNAVAILABLE`, and retries.
- **Chat rules** (`connection.ts`):
  - a call waits until the server's `session` event admits the socket;
  - `connect_error` acts only once socket.io has given up (`!active`). `UNAUTHENTICATED` renews the session; `CONNECTION_FAILED` retries the same token;
  - `disconnect` with `io server disconnect` renews; other reasons only report reconnecting;
  - the backoff resets on `session`, never on `connect`.
- **Unread:** a ticket is unread when `updated_at > lastSeen[id] ?? created_at`. The markers are stored under `davodesk.seen.<channelId>.<sub>`, where `sub` is read from the identity token's payload without verifying it, and cleared on logout.
- **Raising a ticket:** `POST /v1/tickets/me { subject, message }` with `Idempotency-Key`. It answers `{ resumed, ticket }`.
- **host_api:**
  - the pretend customers are `ada` → `{ sub: 'example-ada', name: 'Ada Lovelace', email: 'ada@example.test', email_verified: true }` and `ben` → `{ sub: 'example-ben', name: 'Ben Okafor', email: 'ben@example.test', email_verified: true }`;
  - tokens are HS256 JWTs with `kid` in the header and `exp` 300 s ahead;
  - the port is 8787 by default, on all interfaces;
  - it never prints the secret or a token.
- **No state-management package.** Use `ValueNotifier`, `ChangeNotifier` and `Stream`.
- **Commits** as Hyacinth-Chidi, with no Co-Authored-By trailer. Worktree `../worktrees/davodesk-flutter-client`, branch `feat/client`. Merge with `--no-ff`; never push. Each folder's `flutter analyze` / `dart analyze` stays clean.

## Review Focus

1. **Two screens asking for a session at once** share one open; the identity function is called once. Test: Task 3.
2. **A message sent before the socket is admitted** waits and goes once admitted. With no connection coming (disconnected), it answers `{ ok: false }` and nothing is sent. Test: Task 4.
3. **The same message arriving twice** (a replay after reconnecting) shows once. Test: Task 4.
4. **A ticket whose `updated_at` is before `created_at`** (clock skew) is not unread. Test: Task 5.
5. **A malformed identity token** (no payload part) leaves unread markers under `unknown`, and nothing crashes. Test: Task 5.

---

### Task 1: host_api signs identity tokens

**Files:**
- Create:
  - `host_api/lib/identity.dart`: `String signIdentity({required String keyId, required String secret, required Map<String, Object?> claims, Duration ttl = const Duration(minutes: 5), DateTime? now})`;
  - `host_api/lib/config.dart`: `class HostConfig { apiUrl, channelId, signingKeyId, signingSecret, port }` and `HostConfig.fromEnv(Map<String, String> env)`, which throws `StateError('Missing: <KEY, KEY>')` naming the keys only. Also `Map<String, String> readDotEnv(String path)`, a tiny parser of `KEY=VALUE` lines that skips `#` comments;
  - `host_api/lib/app.dart`: `Handler buildHandler(HostConfig config, {DateTime Function()? now, String Function()? newToken})`;
  - `host_api/.env.example`: the four `DAVODESK_*` keys, plus `PORT=8787`.
- Modify: `host_api/bin/server.dart` (reads `.env`, then `buildHandler`), `host_api/pubspec.yaml` (`crypto`), `host_api/README.md`.
- Test: `host_api/test/identity_test.dart`, `host_api/test/app_test.dart` (in process, calling the handler with `Request`s).

- [ ] **Step 1: Write the failing tests:**
  - `signs HS256 with the key id, expiring in five minutes`: the decoded header is `{"alg":"HS256","typ":"JWT","kid":"sk_1"}`, and the payload is the claims plus `exp` = now + 300. The signature equals base64url (no `=`) of HMAC-SHA256(secret, `header.payload`).
  - `/health` answers `{ "ok": true }`.
  - `/app-config` answers `{ "api_url": …, "channel_id": … }`.
  - `/login` with `ada` → 200 `{ token, name: 'Ada Lovelace' }`; with `carol` → 400.
  - `/support/identity` with that token → 200 `{ identity_token }`, whose payload `sub` is `example-ada`. Without a token, or with an unknown one → 401.
  - `HostConfig.fromEnv` without `DAVODESK_SIGNING_SECRET` throws a message naming it, and containing no value.
- [ ] **Step 2: Run** `cd host_api && dart test`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `dart test` and `dart analyze`. Expected: PASS and clean. **Commit** `feat(host_api): sign identity tokens for the pretend customers`.

### Task 2: Models and API calls

**Files:**
- Create:
  - `davodesk_flutter/lib/src/core/models.dart`, with tolerant `fromJson` constructors (a missing list is empty, a missing string null), as the web widget's `asTicket` does. Classes:
    - `ChannelConfig`: `channelId`, `type`, `brandName`, `supportMode`, `logoUrl`, `headerLogoUrl`, `aiAgentName` (default `'DavoDesk AI'`), `tagline`, `chatNotice`, `answersEnabled`, `aiEnabled`, and `appearance` (`ChannelLook?`: `accentColor`, `title`, `homeLinks`);
    - `OpenedSession`, `ChatMessage` (with `options`, `confirmationRequested`, `botSources`, `attachments`, `senderDisplayName`), `ChatOption`, `TicketSummary`, `LastMessage`, `CustomerTicket` (`messages`, `mergedInto`, `resolvedByAi`, `reopenable`, `satisfaction`), `Satisfaction`, `RaisedTicket` (`resumed`, `ticket`), `PublicArticle`, `ArticleHit`, `CategoryNode`, `ArticlePage`, `SessionSnapshot`;
  - `davodesk_flutter/lib/src/core/api.dart`: `class DavoDeskApi` with `config`, `openSession(channelId, identityToken)`, `logout`, `tickets`, `ticket`, `rate(token, id, {rating, comment})`, `reopen`, `raiseTicket(token, {subject, message, idempotencyKey})`, `attach(token, ticketId, files)`, `search`, `articles(brandId, {categoryId, limit})`, `article`, `categories`, and `vote`. The paths and methods are exactly the web client's.
  - `class DavoDeskApiError implements Exception { final int status; final String? code; final int? retryAfter; final String message; }`.
- Modify: `davodesk_flutter/pubspec.yaml` (`http`), `lib/davodesk_flutter.dart` (export the models, the API and the error).
- Test: `davodesk_flutter/test/core/api_test.dart`, with `http/testing.dart`'s `MockClient`.

- [ ] **Step 1: Write the failing tests:**
  - `opens a session with the channel and identity token, and no Origin`: the body is `{channel_id, identity_token}`, and there is no `origin` header.
  - `sends the bearer token on the customer’s calls`.
  - `raises a ticket with an idempotency key, and reads resumed`: the `Idempotency-Key` header is the given value; `{ resumed: true, ticket: {…} }` gives `RaisedTicket.resumed == true`.
  - `turns a refusal into DavoDeskApiError with code and Retry-After`: `429` with `Retry-After: 7` and `{code:'RATE_LIMITED'}` gives `status 429, code 'RATE_LIMITED', retryAfter 7`.
  - `reads a config with every new field, and defaults the AI name`: `aiAgentName` is `'DavoDesk AI'` when absent, and `appearance` null stays null.
  - `tolerates a ticket message without chat-only fields`: no `options` or `bot_sources` gives empty lists.
- [ ] **Step 2: Run** `cd davodesk_flutter && flutter test test/core/api_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it and `flutter analyze`. Expected: PASS and clean. **Commit** `feat(sdk): models and API calls`.

### Task 3: The session

**Files:**
- Create: `davodesk_flutter/lib/src/core/session.dart`:
  - `sealed class SessionState` with `SessionIdle`, `SessionOpening`, `SessionReady(token, brandId, name, expiresAt)`, `SessionUnavailable(code)` and `SessionLimited(retryAfter)`;
  - `class DavoDeskSession`: constructor `({required DavoDeskApi api, required String channelId, required Future<String?> Function() identityToken, double Function()? random})`; members `state`, `Stream<SessionState> states`, `ensure()`, `renew()`, `logout()`, `dispose()`, and `String? subject`, the `sub` of the last identity token;
  - `Duration backoff(int attempt, double random)`.
- Modify: `pubspec.yaml` (dev: `fake_async`).
- Test: `davodesk_flutter/test/core/session_test.dart`, with `fake_async`.

- [ ] **Step 1: Write the failing tests:**
  - `opens once for callers at the same time`: the identity function is called once for two `ensure()` calls.
  - `renews a minute before it runs out`: with `expires_in: 1800`, a second open happens at 1740 s.
  - `retries with backoff when the identity function fails`: the state is `SessionUnavailable('TOKEN_FAILED')`; with random 0.5 the next try is at 750 ms, then 1500 ms.
  - `waits for Retry-After on 429`.
  - `INVALID_IDENTITY_TOKEN is TOKEN_FAILED; a 401 for the channel is CHANNEL_UNAVAILABLE`.
  - `logout calls the API, stops renewing and goes idle`.
  - `backoff caps at five minutes`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): the customer’s session`.

### Task 4: Live chat and the conversation's state

**Files:**
- Create:
  - `davodesk_flutter/lib/src/core/chat_socket.dart`: `abstract class ChatSocket { bool get active; set auth(Map<String, Object?> value); void on(String event, void Function(Object? data) handler); void connect(); void disconnect(); Future<Object?> emitWithAck(String event, Object? payload); }`, `typedef ChatSocketFactory = ChatSocket Function(Uri url, String token)`, and the `socket_io_client` adapter (websocket transport, auth `{token}`, no auto-connect);
  - `davodesk_flutter/lib/src/core/chat.dart`:
    - `sealed class ChatEvent` with `SessionEvent`, `MessageEvent`, `HandoffEvent`, `HumanJoinedEvent`, `EndedEvent`, `ResolvedEvent`, `ChatErrorEvent` and `ConnectionEvent`;
    - `class DavoDeskChat`: constructor `({required Uri apiUrl, required DavoDeskSession session, ChatSocketFactory? socketFactory, double Function()? random})`; members `Stream<ChatEvent> events`, `connect`, `disconnect`, `restart`, `send`, `choose`, `requestHandoff` and `confirmResolution`;
    - the events it emits are `message`, `option:choose`, `handoff:request` and `resolution:confirm`;
  - `davodesk_flutter/lib/src/core/conversation.dart`: an immutable `Conversation` (`status`, `ticketId`, `messages`, `options`, `agentName` with "not joined" kept apart from "joined, unnamed", `ended`, `connection`, `limitedFor`), `ConversationEvent` (chat events plus `reset`), and `Conversation reduce(Conversation state, ConversationEvent event)`. It ports `conversation.ts` without the email request and code, which only visitors get.
- Modify: `pubspec.yaml` (`socket_io_client`).
- Test: `davodesk_flutter/test/core/chat_test.dart` (a fake socket), `davodesk_flutter/test/core/conversation_test.dart`.

- [ ] **Step 1: Write the failing tests.**

  Chat:
  - `waits for session before sending`: `send('Hi')` resolves only after the fake emits `session`, and the fake records `message {content:'Hi'}`.
  - `answers ok:false with no connection coming`: after `disconnect()`.
  - `renews the session on UNAUTHENTICATED once socket.io gave up`.
  - `retries the same token on CONNECTION_FAILED`.
  - `renews after a server disconnect, and only reports reconnecting otherwise`.

  Conversation, the cases of `conversation.ts`:
  - a replay keeps the snapshot's status;
  - options clear when the customer writes;
  - a message arriving twice shows once;
  - `human_joined` sets `live` and the name;
  - `ended ticket_closed` closes;
  - `RATE_LIMITED` sets `limitedFor`;
  - `reset` keeps `connection`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS. **Commit** `feat(sdk): live chat and the conversation’s state`.

### Task 5: Unread markers and `DavoDeskClient`

**Files:**
- Create:
  - `davodesk_flutter/lib/src/core/unread.dart`: `bool isUnread(TicketSummary t, Map<String, String> seen)`, `int unreadCount(...)`, and `class SeenStore` (`load(channelId, subject)`, `mark(ticketId, at)`, `clear()`) on `shared_preferences`;
  - `davodesk_flutter/lib/src/core/client.dart`: `class DavoDeskClient`. Its constructor is `({required String channelId, required Future<String?> Function() identityToken, Uri? apiUrl, http.Client? httpClient, ChatSocketFactory? socketFactory})`. Its members:
    - `Future<ChannelConfig> config()` (fetched once);
    - `String? get customerName` (from the ready session) and `Future<bool> hasHelpCentre()` (at least one published article, fetched once), for Home;
    - `ValueListenable<Conversation> conversation`;
    - `ValueListenable<List<TicketSummary>> tickets` with `refreshTickets()`;
    - `ValueListenable<int> unread`;
    - `markSeen(ticket)`;
    - `send`, `choose`, `talkToPerson()`, `confirm(bool solved)`, `startNew()`;
    - `openTicket(id)`, `rate`, `reopen`;
    - `Future<RaisedTicket> raiseTicket({required String subject, required String message, String? extraLabel, String? extraValue})`, which puts `"<label>: <value>"` as the first line of the message when the value is not blank, and makes a UUID v4 idempotency key on each call;
    - `attach`, the help-centre calls, `logout()`, `dispose()`.
- Modify: `pubspec.yaml` (`shared_preferences`), `lib/davodesk_flutter.dart` (export `DavoDeskClient`, `Conversation` and the states).
- Test: `davodesk_flutter/test/core/unread_test.dart`, `davodesk_flutter/test/core/client_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - `a ticket changed since it was seen is unread; one never opened counts from when it was raised; clock skew is not unread`.
  - `keeps markers per channel and customer, and clears them on logout`.
  - `a malformed identity token keys markers under unknown`.
  - `raiseTicket puts the extra field on the first line`: message `"Order ID: #VP-8291\n\nMy card…"`; a blank value adds nothing.
  - `unread follows refreshTickets and markSeen`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze`, and `dart test` in host_api. Expected: all pass and clean. **Commit** `feat(sdk): unread markers and DavoDeskClient`. Do the self-review, merge with `--no-ff`, and don't push.
