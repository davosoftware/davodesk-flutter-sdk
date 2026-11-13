# davodesk_flutter

DavoDesk in-app support for Flutter apps: the customer's conversations, help articles and
live chat with your support team, as ready-made screens. The client under them is also
available on its own, for an app that draws its own screens.

**Status:** not published yet; the example app in this repo uses it by path. It needs
Flutter 3.47 or later (Dart 3.13).

## Set up

1. **Add the package** (by path or git until it is published), and make sure your app's
   `pubspec.yaml` has `flutter: uses-material-design: true` for the icons.
2. **Give your backend an identity endpoint.** A DavoDesk session needs an identity token
   that *your* backend signs for the signed-in user (HS256, your signing key's `kid` in
   the header, a few minutes long). The app never holds the signing secret. See
   `support-api/docs/HOST_APP_INTEGRATION.md` §2, and `host_api/` in this repo for a
   working example.
3. **Initialize once the user signs in:**

   ```dart
   await DavoDesk.initialize(
     channelId: 'ch_…', // your brand's app channel
     identityToken: () => myBackend.fetchDavoDeskIdentityToken(), // null when signed out
     theme: const DavoDeskTheme(accent: Color(0xFF1E5AF0)), // optional
     contactForm: const DavoDeskContactForm(
       note: 'We typically respond within 24 hours.',
       extraField: DavoDeskFormField(label: 'Order ID', hint: 'e.g. #VP-8291'),
     ),
   );
   ```

   The identity function is called each time a session opens: at first use, a minute
   before the 30-minute session runs out, after a `401`, and when the app comes back to
   the foreground. Keep it cheap and return a fresh token each time.

4. **Open support:**

   ```dart
   DavoDesk.show(context);                                // Home
   DavoDesk.show(context, page: DavoDeskPage.chats);      // or .help, .contact
   DavoDesk.ask(context, 'Where is my order?');           // a chat, asked
   DavoDesk.openTicket(context, ticketId);                // e.g. from a push notification
   ```

5. **Show the unread count** with `DavoDesk.unread` (a `ValueListenable<int>`), and
   listen to `DavoDesk.events` for opened, closed, unread, a raised ticket, and errors
   (`DavoDeskError('TOKEN_FAILED', …)` when your identity function gives no usable token).
6. **Log out** with `await DavoDesk.logout()` when the user signs out: it closes support,
   ends the session and forgets the user on the device.

## The look

The screens run on your app's navigator as full-screen pages. Out of the box they follow
your app's light or dark setting (the phone's, when your app uses the framework's Material
rather than `material_ui`), take the accent colour and the corners set for the channel in
DavoDesk (its Chat look page), and use DavoDesk's own greys.

To make them match your app, pass a `DavoDeskTheme` to `DavoDesk.initialize`:

```dart
await DavoDesk.initialize(
  channelId: 'ch_…',
  identityToken: () => myBackend.fetchDavoDeskIdentityToken(),
  theme: const DavoDeskTheme(
    accent: Color(0xFF2F6B3F),
    light: DavoDeskColors(
      background: Color(0xFFF6F8F4),
      surface: Color(0xFFE9EEE6),
      text: Color(0xFF14261C),
      border: Color(0xFFD6DECF),
    ),
    dark: DavoDeskColors(
      accent: Color(0xFF6FCF8F),
      background: Color(0xFF0F1A14),
      surface: Color(0xFF0A120E),
      text: Color(0xFFE3EDE6),
      border: Color(0xFF22352A),
    ),
    fontFamily: 'Inter',
    headingFontFamily: 'Poppins',
    corners: DavoDeskCorners.square,
  ),
);
```

| `DavoDeskTheme` | What it sets |
|---|---|
| `accent` | Buttons, the Home header, your customer's chat bubbles, links and icons. It beats the accent set in DavoDesk. |
| `brightness` | Light or dark, whatever the app or the phone says. |
| `light`, `dark` | The screen colours for each, as `DavoDeskColors` (below). |
| `fontFamily` | All the text. Without it, your app's font (an app on `material_ui`) or the platform's. |
| `headingFontFamily` | Page titles, the Home greeting, an article's title and empty states. Without it, `fontFamily`. |
| `corners` | `DavoDeskCorners.rounded` or `DavoDeskCorners.square`, for cards, fields, chat bubbles, labels and buttons. It beats the corners set in DavoDesk; without either, rounded. Avatars stay round. |

| `DavoDeskColors` | What it paints |
|---|---|
| `background` | Pages and cards. |
| `surface` | Text fields, and Home behind its cards: a shade darker than `background`. |
| `text` | The main text. The quieter text (times, hints) and the team's chat bubbles follow it. |
| `border` | Lines and the edges of cards. |
| `accent` | The accent in this mode only; it beats `DavoDeskTheme.accent`. A lighter one usually suits dark. |

A colour you leave out keeps DavoDesk's, so set `background`, `surface` and `border` together.

- **Fonts.** Add the font to your app first (the `fonts:` section of your `pubspec.yaml`),
  then pass its family name. A Google font works too, through the `google_fonts` package:
  `GoogleFonts.inter().fontFamily`.
- **An accent that reads.** Where the accent is text or an icon (links, the Open label, row
  icons, unread dots), the SDK darkens it on light screens or lightens it on dark ones until
  it reads at 4.5:1. Fills (buttons, the Home header, your customer's bubbles) keep your
  colour exactly.
- **What stays DavoDesk's.** The green and amber of the Solved and Reply labels, so a
  ticket's state reads the same in every app. Text size follows the phone's accessibility
  setting.
- **Which wins.** `DavoDeskTheme` in your code, then the accent set in DavoDesk, then
  DavoDesk's blue.

## Platform setup

- **Android:** to open the help links in a browser, add to `AndroidManifest.xml`, inside
  `<manifest>`:

  ```xml
  <queries>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="https" />
    </intent>
  </queries>
  ```

  Add `android:enableOnBackInvokedCallback="true"` to `<application>` for predictive back.
- **iOS:** customers attach photos from their library, so add to `Info.plist`:

  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Attach a photo to your support request.</string>
  ```

## Drawing your own screens

`DavoDeskClient` is what the screens use: the live conversation (`conversation`), the
tickets and the unread count, the contact form's `raiseTicket`, attachments, the help centre,
and `logout`. Create it once the app's binding is ready, call `start()`, and `dispose()` it
when done.

## Calling the API directly

Everything the SDK does goes through the public DavoDesk API, so an app may call it
directly instead: `support-api/docs/HOST_APP_INTEGRATION.md`.
