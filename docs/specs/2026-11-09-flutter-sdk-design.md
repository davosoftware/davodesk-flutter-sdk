# DavoDesk for Flutter: the SDK, its support screens, an example app and its backend

Date: 2026-11-09. Status: written for the owner's review.

## 1. What the owner asked for

- **A Flutter SDK**, built while the owner tests the web widget. Developers can still use
  the API directly if they don't want the SDK.
- **A test Flutter app** for it, and **a test API for that app**, with **clean folder
  separation**.
- **The SDK includes the support UI.** The owner said "support ui for the sdk", meaning
  ready-made screens, not only a client.
- The folders were made on 2026-11-09 in a new repo, `davodesk-flutter/` (commit
  `e4f25e4`):

| Folder | What it is |
|---|---|
| `davodesk_flutter/` | The SDK: a Flutter package, the support screens and the client under them |
| `example_app/` | A pretend company app ("Acme") that uses the SDK by path |
| `host_api/` | The pretend company's backend, in Dart: it signs identity tokens |

## 2. Why, and what success looks like

The owner's company used the Zendesk SDK inside its own app, and DavoDesk is its
replacement (the product's wedge). The web widget covers websites; this covers apps.

Success: an app developer adds the package and gives it two things:
- the channel id;
- a function that fetches an identity token from their own backend.

Then `DavoDesk.show(context)` gives their signed-in customers what the web panel gives:
Home, Messages, Help, live chat with an agent by name, tickets, and DavoDesk AI. It looks
and feels like part of the app.

**Anti-goals.** Any of these makes it a failure even if it works:
- The signing secret, or anything that can mint a token, inside the app.
- A feature only the SDK can do. Everything goes through the public API, which stays the
  documented alternative.
- Screens that feel like a web page in an app: no WebView.
- Forcing a state-management library (Provider, Riverpod, Bloc) on the host app.
- Keeping the session token on disk. The integration guide (§10) says memory only.

## 3. The SDK's public calls

```dart
await DavoDesk.initialize(
  channelId: 'ch_…',                       // the brand's app channel
  identityToken: () => myBackend.supportIdentityToken(),   // called whenever a session opens
  apiUrl: 'https://api.davodesk.com',      // optional; production by default
  theme: DavoDeskTheme(accent: Colors.teal),   // optional; overrides the channel's colour
);

DavoDesk.show(context);                                 // Home
DavoDesk.show(context, page: DavoDeskPage.messages);    // or .help
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
- **The client under the screens** is exported as `DavoDeskClient`, for an app that draws
  its own screens. It covers:
  - the live conversation, as a stream of states;
  - the customer's tickets and one ticket, rating and reopening;
  - attachments;
  - help-centre search, collections, articles and votes;
  - logout.
- **No state-management dependency.** Internally it uses Flutter's own `ValueNotifier`,
  `ChangeNotifier` and streams.

## 4. The support screens

They mirror the web panel as it stands on 2026-11-06, adapted to a phone:

- **Presentation.** `show` pushes a full-screen route on the app's navigator. Back and
  the system back gesture work as people expect.
- **Home:**
  - the blue header: the brand's logo on a white tile (the initial when there is none or
    it fails to load), the title, and close;
  - "Hi {first name}, how can we help?", and the "Ask a question" box;
  - cards below it:
    - your recent conversation;
    - the brand's questions (FAQ);
    - Message the team;
    - the channel's home links;
    - Powered by DavoDesk with the DavoDesk logo;
  - tabs at the bottom: Home, Messages, Help.
- **Messages:**
  - a back arrow to Home, the centred title, and no tab bar;
  - each conversation shows its subject, day, who wrote last, its state and reference, and
    an unread dot;
  - "Message the team" in a bar at the bottom.
- **Help:**
  - search, collections, their articles, and an article with "Was this helpful?";
  - the tab is hidden when the brand has no published articles.
- **A conversation:**
  - "{agent} joined", and the agent's name on their messages ("{brand} team" when they
    have none);
  - the FAQ's and intake's choices;
  - DavoDesk AI's "Did this solve it?" with "That solved it" and "Talk to a person";
  - the reference in the header;
  - "Reconnecting…", and "Too many messages. Try again in a minute.";
  - the composer, with attachments;
  - a closed ticket shows "This conversation was closed." and **Start a new
    conversation** in place of the composer.
- **A ticket:**
  - a state chip, with the web widget's labels: Open, Reply (the team is waiting for the
    customer), Solved, or Closed in grey;
  - its messages;
  - the rating when the team asked;
  - Reopen for a solved ticket; a closed ticket is final.
- **Brands that only answer** (the assistant-only mode) get Home and Help, with no
  Messages, as on the web.
- **Signed-in customers only.** App channels have no visitors (guide §10), so there is no
  visitor flow and no email request; the API asks only visitors for an email.
- **Look:**
  - the channel's accent colour (§5), or DavoDesk blue, unless `DavoDeskTheme` overrides
    it;
  - light or dark following the app;
  - the app's own fonts, so it reads as part of the app;
  - our cards and spacing, not stock Material defaults.
- **Accessibility:** every control has a label for screen readers, text scales with the
  phone's setting, and tap targets are at least 48 px.
- **Errors:** a screen that fails to draw shows "Something went wrong here." with Start
  again, as on the web, instead of a red error screen.
- **English only** for now, like the web panel.

## 5. A change in the API and DavoDesk: app channels get a look

Today the API refuses `appearance` on an app channel ("it draws its own screens"). With
the SDK's screens, an app channel takes three of the website channel's settings:
- `accent_color`;
- `title`;
- `home_links`.

`launcher_position` and `launcher_label` stay website-only: a 400 on an app channel.
DavoDesk's app channel page gains the Look section with those three fields. The public
config carries them as it does for a website. The support team can then change the colour
and links without the app shipping a new version.

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
  - `url_launcher` (home links).

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
  - **Sign out** (`DavoDesk.logout`, then back to sign in).
- **The host API's address** is a setting kept on the device. The default is
  `http://10.0.2.2:8787` on the Android emulator and `http://localhost:8787` on the iOS
  simulator.
- Plain `http` to a local API and host API is allowed in debug builds only.
- It sets its own colour once through `DavoDeskTheme`, to show the override working.

## 9. Testing

- **The SDK:**
  - the client tested with a fake HTTP client and a fake socket;
  - each screen tested with Flutter's widget tests;
  - the session rules (expiry, `401`, `CONNECTION_FAILED`, backoff) tested on their own.
- **The host API:** the token's signature checks out with the secret; the claims and
  expiry are right; unknown tokens get `401`.
- **The example app:** smoke tests.
- **On the Android emulator:**
  - the example app against my own API on port 3100, with a test brand, an app channel and
    a signing key;
  - screenshots of every screen, light and dark.

  This writes to the development database, so it waits for the owner's OK.
- **iOS** can't be built on this Windows machine. The code is shared, the plugin setup is
  documented, and running it on an iPhone waits for a Mac.

## 10. Not now

- **Push notifications.** Delivering them is the app's job: the API calls the company's
  webhook (guide §9). The SDK gives `openTicket` for a notification tap, and the unread
  count.
- Visitors and the email request: app channels have none.
- Taking a photo with the camera inside the SDK. Picking existing photos and files is in.
- Other languages, an offline message queue, and publishing to pub.dev with its licence.
- SDKs for Swift, Kotlin and React Native, and a webhook receiver in the host API.

## 11. Calls I made, for the owner to check

- **Full-screen pages** on the app's navigator, not a bottom sheet or a floating bubble.
- **The app's own fonts** rather than the web widget's font.
- **App channels get colour, title and links** in DavoDesk (§5), with the colour also
  settable in code.
- **The host API in Dart**, so the repo needs only Flutter's tools.
- **No camera capture** in the first version.

## 12. A question only the owner can answer

- **Which Flutter version is your company's app on?** It sets the oldest Flutter the SDK
  supports. Until then the floor is the version tested here (Flutter 3.47, Dart 3.13), which
  may be newer than your app.
