## 0.0.1 (unreleased)

Taken from this repo by git until it is published; `flutter pub upgrade davodesk_flutter`
brings in the newest.

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
