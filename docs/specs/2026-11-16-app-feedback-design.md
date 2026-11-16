# App feedback after the first live test: design

**Date:** 2026-11-16. **Source:** the Davochain app developer's feedback after DavoDesk went live in
their Android app (`davodesk_flutter` at `b06882c`). **Repos:** `davodesk-apps` (API, DavoDesk,
widget) and `davodesk-flutter-sdk`.

**The owner's decisions (2026-11-16):**
1. "Send us a message" with a **different subject starts a new request**; the same subject, or no
   subject, joins the customer's open request as today. The app says where the message went.
2. The chat fixes go into **the web widget too**, not only the SDK.
3. Typing dots for **DavoDesk AI and the team, now**.
4. **No voice feature:** dictation is the phone keyboard's job, nothing to do with DavoDesk.

## Why

A customer who sends a message must see it at once and know an answer is coming. Today the
bubble can vanish until DavoDesk AI replies, an open chat misses a message the customer added
through "Send us a message", and that message silently joins an older request about something
else. These are the first things a real customer notices.

## Goals

1. A sent message shows at once as **"Sending…"**, then as sent, or as **"Not sent · Retry"**.
   SDK and widget.
2. **Typing dots** while DavoDesk AI or a team member writes a reply. API, DavoDesk, widget, SDK.
3. **The open chat stays current:** it refreshes when it opens, when the customer comes back to the
   app or the tab, and on pull-to-refresh in the app. A message the customer adds to the chat's
   request through "Send us a message" appears in the chat. API, widget, SDK.
4. **"Send us a message" joins an open request only for the same subject;** the app shows where the
   message went. API, SDK.
5. The contact form's intro is **neutral by default** and **the app can set its own**. SDK.
6. The chats list shows **the brand's tile, or the team member's initial**, never the customer's own
   "Y". SDK and widget.
7. **No debug assertion** on "Start a new chat" from Chats while Home is open; **the attachment
   sheet and the text toolbar work** in apps on Flutter's own Material. SDK.
8. **New bubbles slide in gently,** with no motion when the phone or browser asks for less. SDK and
   widget. The chat in the app keeps its newest line in view reliably.

## Non-goals

- Voice, dictation or audio of any kind.
- Showing the customer's typing to the team.
- Read receipts.

## Anti-goals (a failure even if everything else works)

- The team writing an **internal note** ever shows as typing to a customer.
- A message that was actually sent is marked "Not sent", so Retry sends it twice.
- Host apps must add new permissions or code for any of this.

## Design

### 1. Sending (API, widget, SDK)

- The customer's `message` event takes an optional **`client_id`** (1–64 characters). The API puts it
  back on the customer's copy of that message (`client_id` on the message the customer's sockets
  receive; never on the team's copy, and absent when none was sent).
- On send, the client adds the customer's bubble at once with its own `client_id`, marked
  "Sending…". The echoed message with the same `client_id` replaces it. An echo without
  `client_id` (an API from before this change) replaces the oldest "Sending…" bubble with the same
  text.
- The send's acknowledgement with `ok: false` **before** the echo marks the bubble "Not sent ·
  Retry". Retry removes it and sends the same text as a new message. While the socket is down, the
  bubble stays "Sending…"; a send that gives up marks it "Not sent".
- A choice tapped from a reply's buttons is not given a "Sending…" bubble: the buttons go, and the
  echo comes as it does today.

### 2. Typing (API, DavoDesk, widget, SDK)

- New event to the customer's sockets: **`typing`** `{ by: 'ai' | 'team', typing: boolean, name?: string }`.
- **DavoDesk AI:** `{ by: 'ai', typing: true }` when it starts on a customer's message;
  `{ by: 'ai', typing: false }` when its answer is sent or the turn ends any other way.
- **The team:** DavoDesk's reply box adds `reply: true` to the `ticket:typing` it already sends to
  colleagues, and only while writing a **reply**; switching to a note sends `typing: false`. The API
  forwards reply typing to the ticket's open chats (awaiting a person, or live) as
  `{ by: 'team', typing, name }`, `name` being the member's display name. Note typing, or typing
  without `reply: true`, is **never** forwarded.
- **Clients** show one typing bubble at the bottom: for DavoDesk AI, the bot's run head (tile and
  name) over three dots; for the team, the person's name over three dots. It goes when a message from
  that party arrives, on `typing: false`, or 8 seconds after the last `typing: true`.

### 3. Refresh (API, widget, SDK)

- New customer event **`session:sync`**: the API answers that socket alone with `session`, the same
  snapshot it sends on connecting.
- **SDK:** syncs when the chat page opens on a connected socket, when the app returns to the
  foreground, and on pull-to-refresh. **Widget:** when the panel opens and when the tab becomes
  visible again.
- **API:** a message the customer adds to a request through "Send us a message" is copied into that
  request's open chats, exactly as a team reply written on the ticket already is, so the chat shows
  it live.

### 4. Open requests (API, SDK)

- A request created with one of the brand's request subjects stores **`request_subject_key`**.
- Raising a request:
  - with a subject the brand has: join the **most recently updated** open request with the same
    `request_subject_key`; otherwise create a new request;
  - without one (none chosen, or the brand has none): join the most recently updated open request,
    as today; otherwise create one.
- An open request from before this change has no key, so a chosen subject starts a new request.
- A chat handing over to the team keeps joining the open request, now deterministically the most
  recently updated one.
- The answer's `resumed` and `notice` are unchanged.
- **SDK:** the request page that opens after sending shows a banner at its top: "Added to your open
  request #8DEE9D" when it joined, "Sent. We'll reply here." when new.

### 5. Contact intro (SDK)

- `DavoDeskContactForm(intro: …)` sets the line; the default becomes "Have a question? Our team is
  here to help."

### 6. Chats list avatar (SDK, widget)

- The last message from a **team member**: their initial, as today. **Anything else** (the customer,
  DavoDesk AI, an automation): the brand's tile, the logo or the brand's initial, as in the chat's
  header.

### 7. SDK fixes

- **Start a new chat** starts the fresh conversation just after the page's first frame, so no other
  page is rebuilt during a build.
- **The attachment sheet and the text toolbar** open in the app's overlay, outside the SDK's page;
  they get the SDK's localizations and theme themselves.

### 8. Motion and scrolling (SDK, widget)

- A new bubble, or the typing bubble, fades in and rises 8 px over about 180 ms. Bubbles already
  there on first load don't animate. Nothing moves when the phone asks for less animation
  (`MediaQuery.disableAnimations`) or the browser for reduced motion; the typing dots then hold
  still.
- **SDK:** the chat list is anchored at the bottom, so a new line is always in view.

## Compatibility and order

- Deploy the **API first**, then DavoDesk and the widget, then push the SDK.
- An older client ignores `typing` and never sends `client_id` or `session:sync`; an older API
  ignores both too, and the clients fall back as described. Nothing breaks either way round.

## Docs and answers

- `HOST_APP_INTEGRATION.md`: `client_id`, `typing`, `session:sync`, and the subject rule; the raise
  route's description in the public reference.
- The SDK's README and CHANGELOG: `intro`, sending, typing and refresh.
- A reply to the app developer, with answers to their earlier open questions.

## Left to the builder

- Exact visuals inside DavoDesk's look, test names, and how each client stores its pending bubbles.
