## 0.0.1 (unreleased)

Taken from this repo by git until it is published; `flutter pub upgrade davodesk_flutter`
brings in the newest.

### 2026-11-16: App feedback

- A sent message shows at once as "Sending…", then as sent; one the server refuses shows
  "Not sent" with Retry.
- Typing dots while DavoDesk AI writes an answer, or someone on the team a reply, with
  their name.
- The chat asks for what it missed when it opens, when the app comes back to the
  foreground, and on pull-to-refresh; a message sent through the contact form shows in it.
- In a long chat the newest line stays in view, the typing dots included, and when the
  keyboard opens. A new bubble fades in and rises, unless the phone asks for less motion.
- `DavoDeskContactForm.intro` sets the contact form's first line; without it, "Have a
  question? Our team is here to help." (it used to speak of an order). After sending, the
  request opens saying where the message went: "Added to your open request #…" or "Sent.
  We'll reply here."
- A contact-form message joins the open request only when its subject is the same, or
  none; another subject starts a new request.
- The chats list shows the initial of the team member who answered last, or else the
  brand's logo, no longer the customer's own initial.
- Fixed: Start a new chat from Chats while Home was open raised a `setState()` during
  build assertion.
- Fixed: in an app on Flutter's own Material, the attachment sheet and the text toolbar
  raised "No MaterialLocalizations found" (on iOS, "No CupertinoLocalizations found"). An
  app that added `material_ui` localizations to get past it can remove them.
- Works best on the DavoDesk API from 2026-11-16, which sends typing and answers a
  refresh. On an older API the chat still works, without the dots or the refresh.

### 2026-11-13: Chat look

- The bot's replies show the brand's logo and the bot's name, both set in DavoDesk, once
  per run of replies; ✦ marks the replies DavoDesk AI wrote. The "AI Agent" label is gone.
- The corners follow the setting in DavoDesk unless `DavoDeskTheme.corners` sets them.
  `DavoDeskTheme.corners` is now optional; it used to default to `rounded`.
- The look is read again each time support opens, so a change saved in DavoDesk shows
  without a new release of the app. Support waits up to two seconds for it, and on a
  slower network opens with the last look.

### Before that

- The support screens: Home, chats, help articles, the contact form and tickets, with live
  chat and attachments.
- `DavoDeskTheme` for the app's own colours, fonts and corners, and `DavoDeskContactForm`
  for the contact form's note and extra field.
- `DavoDesk.unread`, `DavoDesk.events` and `DavoDesk.logout`, and `DavoDeskClient` for an
  app that draws its own screens.
