# DavoDesk for Flutter: the SDK, its support screens, an example app and its backend

Date: 2026-11-09. Status: approved by the owner on 2026-11-09 ("no voice, other
approved").

## 1. What the owner asked for

- **A Flutter SDK**, built while the owner tests the web widget. Developers can still use
  the API directly if they don't want the SDK.
- **A test Flutter app** for it, and **a test API for that app**, with **clean folder
  separation**.
- **The SDK includes the support UI** (the owner: "support ui for the sdk").
- **The screens follow the owner's own Davopay design** (five frames, 2026-11-09):
  - Home: Messages and Help as rows, Send us a message, the links, and no tabs;
  - Messages with an empty state;
  - a chat with a named AI agent ("Callie · AI Agent"), a notice and a tagline, and the
    FAQ as chips;
  - an Email Support form.

  The mockup that follows those frames was approved, with this split:

| Part of the design | When |
|---|---|
| The AI agent's own name per brand | First version |
| A notice at the top of the chat | First version |
| A tagline under the chat header | First version |
| A second logo for the coloured header | First version |
| Voice notes | **Not planned** (the owner, 2026-11-09: "no voice") |
| Order ID as a real field (in the message for now) | Later |
| The emoji button and the chips | No API work |

- **Full screen,** as the owner's frames show; there is no bottom sheet.
- The folders were made on 2026-11-09 in a new repo, `davodesk-flutter/` (commit
  `e4f25e4`):

| Folder | What it is |
|---|---|
| `davodesk_flutter/` | The SDK: a Flutter package, the support screens and the client under them |
| `example_app/` | A pretend company app ("Acme") that uses the SDK by path |
| `host_api/` | The pretend company's backend, in Dart: it signs identity tokens |

The approved mockup is kept as `davodesk-flutter/docs/specs/2026-11-09-flutter-sdk-screens.html`.

## 2. Why, and what success looks like

The owner's company (Davopay) used the Zendesk SDK inside its own app. DavoDesk is its
replacement, and Davopay is customer zero. The web widget covers websites; this covers apps.

Success: an app developer adds the package and gives it two things:
- the channel id;
- a function that fetches an identity token from their own backend.

`DavoDesk.show(context)` then gives their signed-in customers the screens above, with the
company's own logo, colour, links, AI agent name, notice and tagline. Davopay's app looks
like Davopay's design; another company's app looks like itself.

**Anti-goals.** Any of these makes it a failure even if it works:
- The signing secret, or anything that can mint a token, inside the app.
- A feature only the SDK can do. Everything goes through the public API, which stays the
  documented alternative.
- Screens that feel like a web page in an app: no WebView.
- Forcing a state-management library (Provider, Riverpod, Bloc) on the host app.
- Keeping the session token on disk. The integration guide (§10) says memory only.
- Davopay's details written into the SDK. They come from Davopay's settings.

## 3. The SDK's public calls

```dart
await DavoDesk.initialize(
  channelId: 'ch_…',                       // the brand's app channel
  identityToken: () => myBackend.supportIdentityToken(),   // called whenever a session opens
  apiUrl: 'https://api.davodesk.com',      // optional; production by default
  theme: DavoDeskTheme(accent: Colors.teal),   // optional; overrides the channel's colour
  emailForm: DavoDeskEmailForm(            // optional; the Email Support form's own words
    note: 'We typically respond to all email inquiries within 24 hours.',
    extraField: DavoDeskFormField(label: 'Order ID', hint: 'e.g. #VP-8291'),
  ),
);

DavoDesk.show(context);                                 // Home
DavoDesk.show(context, page: DavoDeskPage.messages);    // or .help, .email
DavoDesk.ask(context, 'Where is my order?');            // opens a conversation, asked
DavoDesk.openTicket(context, ticketId);                 // e.g. from a push notification
DavoDesk.unread;                 // ValueListenable<int>: unread conversations, for a badge
DavoDesk.events;                 // Stream: opened, closed, unread(count), ticket(id, reference), error
await DavoDesk.logout();         // when the app's user signs out
```

- **Same ideas as the web SDK** (widget SDK spec §6): a channel id, the customer's token,
  `logout`, `open`/`show`, `ask` and the same events.
- **Identity is a function, not a token.** A session lasts 30 minutes and can't be
  refreshed, so the SDK calls the function each time it opens one. Each call runs on open,
  before expiry, after a `401`, and when the app resumes. When the app's user changes,
  the app calls `logout()`; the function then returns the new user's token.
- **The email form's words are set in code**, since they belong to the app.
  - **The note** is the line in the highlighted card. Without one, the card isn't shown.
  - **The extra field** is optional, and its value goes into the message as a first line
    ("Order ID: #VP-8291") until tickets get real customer fields (later).
- **The client under the screens** is exported as `DavoDeskClient`, for an app that draws
  its own screens. It covers:
  - the live conversation, as a stream of states;
  - the customer's tickets and one ticket, rating and reopening;
  - raising a ticket from the email form;
  - attachments;
  - help-centre search, collections, articles and votes;
  - logout.
- **No state-management dependency.** Internally it uses Flutter's own `ValueNotifier`,
  `ChangeNotifier` and streams.

## 4. The support screens

They follow the approved mockup, which follows the owner's frames:

- **Home:**
  - the brand's colour fading to the page behind the cards;
  - **the header logo** (§5.4) in white space at the top left, or the brand's name in bold
    when there is none, and close at the top right;
  - "Hi {first name} 👋" and "How can we help?" ("Hi there 👋" without a name);
  - a conversation in progress, as a card at the top, as on the web;
  - a card with **Messages** and **Help** rows. Help is hidden when the brand has no
    published articles. An assistant-only brand has no Messages row;
  - **Send us a message**, which opens the Email Support form;
  - the channel's **links**, each with an "opens outside" icon;
  - **Powered by DavoDesk**, small, at the bottom;
  - no tabs.
- **Messages:**
  - back, the centred title, and a pencil (a new conversation) and close in the header;
  - each conversation shows its subject, day, who wrote last, its state and reference, and
    an unread dot;
  - **empty:** "No Messages", "Messages from the team will be shown here", and **Ask a
    question**.
- **A conversation:**
  - **While DavoDesk AI answers,** the header shows the brand's square logo (the initial
    without one), **the AI agent's name** (§5.2), and "The team can also help".
  - **Once a person joins,** the header shows their name, and "{brand} team · #reference".
  - **At the top of the chat:** the brand's **tagline** (§5.3), then the **notice** (§5.3)
    when the team has one switched on.
  - **The AI's messages** are labelled "{agent name} · AI Agent". A person's messages
    carry their name, and "{agent} joined" marks when they joined.
  - **The FAQ's and intake's choices** are chips, right-aligned. The message box is hidden
    while the conversation waits for a choice, and appears with the next free-text step
    or "Something else".
  - **DavoDesk AI's "Did this solve it?"** offers "That solved it" and "Talk to a person"
    as chips.
  - **The message box:** "Ask a question…" (or "Write a message…" once a person is
    there), attachments, emoji, and a send arrow that turns the brand's colour when there's
    text. There is no microphone: the owner ruled out voice notes.
  - "Reconnecting…", and "Too many messages. Try again in a minute.".
  - **A closed ticket** shows "This conversation was closed." and **Start a new
    conversation** in place of the box.
- **Email Support** (from Send us a message, or `page: .email`):
  - "Email Us", "Have a question about your order or our services? Our team is here to
    help.", the note's card when set, **Subject**, the extra field when set
    (marked OPTIONAL), **Message**, and **Send Email**;
  - sending raises a ticket (§6), then says "Sent. We'll reply here and by email." and
    opens it;
  - when the customer already has an open request, the API adds to it rather than opening
    a second one. The confirmation then says "Added to your open request #ref".
- **Help:** search, the brand's collections, their articles, and an article with "Was this
  helpful?".
- **A ticket:**
  - a state chip with the web widget's labels: Open, Reply (the team is waiting for the
    customer), Solved, or Closed in grey;
  - its messages;
  - the rating when the team asked;
  - Reopen for a solved ticket; a closed ticket is final.
- **Signed-in customers only.** App channels have no visitors (guide §10), so there is no
  visitor flow and no email-address request; the API asks only visitors for an email.
- **Look:**
  - the channel's accent colour (§5.1), or DavoDesk blue, unless `DavoDeskTheme`
    overrides it;
  - light or dark following the app;
  - the app's own fonts;
  - cards and spacing as in the mockup, not stock Material defaults.
- **Accessibility:** every control has a label for screen readers, text scales with the
  phone's setting, and tap targets are at least 48 px.
- **Errors:** a screen that fails to draw shows "Something went wrong here." with Start
  again, instead of a red error screen.
- **English only** for now, like the web panel.

## 5. What the API and DavoDesk gain

1. **App channels get a look.**
   - The API takes three of the website channel's settings on an app channel:
     `accent_color`, `title` and `home_links`.
   - `launcher_position` and `launcher_label` stay website-only: a 400 on an app channel.
   - DavoDesk's app channel page gains the Look section with those three fields.
2. **The AI agent's name, per brand.**
   - `ai.agent_name` lives on the brand's DavoDesk AI settings: 1 to 40 characters, no
     control characters, "DavoDesk AI" when unset.
   - It's set on the brand's DavoDesk AI page in DavoDesk.
   - The public config carries `ai_agent_name`.
   - The web widget uses it too, in place of the "DavoDesk AI" it writes today (the last
     message's "DavoDesk AI:" line), so a brand's website and app say the same name.
   - DavoDesk's own screens for staff keep saying DavoDesk AI.
3. **The tagline and the notice, per brand.**
   - `tagline`: up to 80 characters, or null.
   - `chat_notice: { enabled, text }`: the text is up to 300 characters, and turning the
     notice off keeps the text for next time.
   - Both are set on the brand page in DavoDesk, the notice with an on/off switch, since
     the team turns it on at busy times.
   - The public config carries `tagline` and `chat_notice`, which is the text when on and
     null when off.
4. **The header logo**, a second upload beside the logo:
   - `PUT /v1/brands/:id/header-logo` and `DELETE` work like the logo, with the same
     types, limit, storage and refusals.
   - It is **kept in its own shape**: fitted inside 600 × 160, never padded to a square,
     because it's a wordmark.
   - The public config and `BrandDto` carry `header_logo_url`.
   - DavoDesk's Logo panel shows both uploads, each with its own preview: the header logo
     on the brand's colour, and the square logo on its white tile. The hint asks for a
     white or light version, since it sits on the colour.
5. **Not changed:** tickets (`POST /v1/tickets/me` already takes a subject and message),
   attachments, chat, and the Platform console.

## 6. Under the screens

- **Opening a session:**
  - It calls the identity function, then `POST /v1/end-user-sessions` with `channel_id`
    and `identity_token`. No `Origin` is sent; it is a native app.
  - The session token is kept in memory only.
  - A new session opens before expiry, on a `401`, on the socket's `UNAUTHENTICATED`, and
    on app resume, with a backoff that grows to minutes.
  - `CONNECTION_FAILED` retries the same token.
  - This follows guide §2 and §4, the same rules as the web widget's session code.
- **Live chat:** the `/chat` Socket.IO namespace with `auth: { token }`, the same events
  and acknowledgements as the web widget. It doesn't rely on the library to reconnect
  after a server disconnect.
- **The email form:**
  - `POST /v1/tickets/me { subject, message }` with an `Idempotency-Key` made when Send is
    tapped and reused on retries (guide §8);
  - `resumed: true` in the answer means it was added to the open request.
- **The rest:** the REST calls the web widget makes, in five groups:
  - channel config;
  - session and logout;
  - `tickets/me` (the list, a ticket, satisfaction, reopen);
  - attachments;
  - help centre (search, collections, list, article, vote).
- **Unread.** Each conversation's last-seen time is kept on the device. The key is the
  channel plus the identity token's `sub` claim, which the SDK reads without trusting it.
  These markers are cleared on logout. They are the only thing stored.
- **Attachments:** photos and files picked with the system picker, checked against the
  API's types and size before upload, then sent the standard multipart way.
- **Packages the SDK adds:**
  - `http`;
  - `socket_io_client` (Socket.IO v4, as the API runs);
  - `shared_preferences` (the unread markers);
  - `file_picker`;
  - `url_launcher` (links).

  The README lists the one-time platform setup they need, such as Android's link queries
  and iOS's photo-library text.

## 7. The test backend (`host_api/`)

A small Dart server standing in for the company's own backend. It shows the pattern the
guide recommends and keeps the secret off the phone.

- **Settings** in `host_api/.env`, which is git-ignored; `.env.example` lists the keys:
  - `DAVODESK_API_URL`;
  - `DAVODESK_CHANNEL_ID`;
  - `DAVODESK_SIGNING_KEY_ID`;
  - `DAVODESK_SIGNING_SECRET`.
- `GET /health`.
- `GET /app-config` → `{ api_url, channel_id }`. Neither is secret, and the tester sets
  everything in one place.
- `POST /login { "customer": "ada" | "ben" }` → `{ token, name }`. This is pretend sign-in
  with no password; it is a test server.
- `GET /support/identity` with that token as a bearer → `{ identity_token }`:
  - signed HS256 with the key id in the header, expiring in 5 minutes;
  - claims `sub`, `name`, `email` and `email_verified: true`;
  - an unknown token gets `401`.
- **The pretend customers** are those of the web playground: Ada Lovelace
  (`example-ada`) and Ben Okafor (`example-ben`).
- It listens on all interfaces, port 8787, so the Android emulator reaches it at
  `10.0.2.2:8787`.
- It never prints the secret or a token.

## 8. The example app (`example_app/`)

- **Sign in** as Ada or Ben, through the host API.
- **Acme's home:**
  - "Hi Ada";
  - a **Help** button with the unread badge;
  - **Ask about my order** (`DavoDesk.ask`);
  - **Email us** (`page: .email`, with an Order ID field and a note, to show the form's
    settings);
  - **Sign out** (`DavoDesk.logout`, then back to sign in).
- **The host API's address** is a setting kept on the device. The default is
  `http://10.0.2.2:8787` on the Android emulator and `http://localhost:8787` on the iOS
  simulator.
- Plain `http` to a local API and host API is allowed in debug builds only.

## 9. Testing

- **The SDK:**
  - the client tested with a fake HTTP client and a fake socket;
  - each screen tested with Flutter's widget tests, against the approved mockup's words;
  - the session rules (expiry, `401`, `CONNECTION_FAILED`, backoff) tested on their own.
- **The API and DavoDesk:** the usual unit and e2e tests for the new settings, the header
  logo, and the app channel's look.
- **The web widget:** the AI agent's name in place of "DavoDesk AI".
- **The host API:** the token's signature checks out with the secret; the claims and
  expiry are right; unknown tokens get `401`.
- **The example app:** smoke tests.
- **On the Android emulator:**
  - the example app against my own API on port 3100, with a test brand, an app channel and
    a signing key;
  - screenshots of every screen, light and dark, compared with the approved mockup.

  This writes to the development database, so it waits for the owner's OK.
- **iOS** can't be built on this Windows machine. The code is shared, the plugin setup is
  documented, and running it on an iPhone waits for a Mac.

## 10. Not now

- **Order ID as a real ticket field** the team can filter on. Until then it is a line in
  the message.
- **The notice, tagline and header logo on the web widget.** Only the AI agent's name goes
  there now.
- **Push notifications.** Delivering them is the app's job: the API calls the company's
  webhook (guide §9). The SDK gives `openTicket` for a notification tap, and the unread
  count.
- Visitors, and the email-address request: app channels have none.
- Taking a photo with the camera inside the SDK. Picking existing photos and files is in.
- Other languages, an offline message queue, and publishing to pub.dev with its licence.
- SDKs for Swift, Kotlin and React Native, and a webhook receiver in the host API.

## 11. Calls I made, for the owner to check

- **"Send us a message" opens the Email Support form,** and chat starts from Messages
  (Ask a question, the pencil) or `DavoDesk.ask`.
- **The email form's first field is "Subject".** The frames labelled two fields "Message".
- **The email form's note and extra field are set in the app's code,** not in DavoDesk.
- **The AI agent's name also replaces "DavoDesk AI" in the web widget,** so a brand
  speaks with one name.
- **The header logo is a second upload,** so the square logo stays as it is.
- **The app's own fonts,** and **the host API in Dart.**
- **No camera capture** in the first version.

## 12. A question only the owner can answer

- **Which Flutter version is your company's app on?** It sets the oldest Flutter the SDK
  supports. Until then the floor is the version tested here (Flutter 3.47, Dart 3.13), which
  may be newer than your app.
