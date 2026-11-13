# davodesk_flutter

DavoDesk in-app support for Flutter apps: the customer's conversations, help articles and
live chat with your support team, as ready-made screens. The client under them is also
available on its own, for an app that draws its own screens.

**Status:** not on pub.dev yet; your app takes it from this private GitHub repo. It needs
Flutter 3.47 or later (Dart 3.13).

## Before you start

You need three things:

- **Read access to this repo** (`github.com/davosoftware/davodesk-flutter-sdk`): ask its
  owner to add your GitHub account. `flutter pub get` then fetches the package with your
  own git login.
- **The brand's app channel id** (`ch_…`). In DavoDesk, open **Developer → Connect your
  apps** (`https://app.davodesk.com/settings/developer?tab=connect`), pick the brand, and
  copy the **App** channel's id. An Owner, Admin or Developer of the organisation can open
  that page, or give you the id and a key. No App channel? An Owner or Admin adds it in the
  brand's setup, under **Where customers reach you**.
- **A signing key** for your backend, on the same tab: **Signing keys → New key**. Copy the
  key id and the secret into your backend's settings. The secret never goes into the app.

## Set up

1. **Add the package** to your app's `pubspec.yaml`, which also needs
   `flutter: uses-material-design: true` for the icons:

   ```yaml
   dependencies:
     davodesk_flutter:
       git:
         url: https://github.com/davosoftware/davodesk-flutter-sdk.git
         path: davodesk_flutter
         ref: main
   ```

   `flutter pub get` locks the commit it fetched in `pubspec.lock`; `flutter pub upgrade
   davodesk_flutter` takes the newest. With an SSH key on GitHub, the url
   `git@github.com:davosoftware/davodesk-flutter-sdk.git` works too.
2. **Give your backend an identity endpoint.** A DavoDesk session needs an identity token
   that *your* backend signs for the signed-in user; the app fetches one from your backend
   and never holds the signing secret. The token is a JWT:

   - signed with HS256 and your signing key's secret, with the key id as `kid` in its
     header;
   - `sub`: your own stable id for the user, 1–256 characters, never taken from the device;
   - `exp`: a few minutes ahead (at most an hour);
   - optional `name`, `email` and `phone`, and `email_verified: true` only for an email you
     have verified.

   In Node, behind your app's own sign-in:

   ```js
   import jwt from 'jsonwebtoken';

   app.get('/support/identity', requireSignedIn, (req, res) => {
     const identityToken = jwt.sign(
       { sub: req.user.id, name: req.user.name, email: req.user.email },
       process.env.DAVODESK_SIGNING_SECRET,
       { algorithm: 'HS256', keyid: process.env.DAVODESK_SIGNING_KEY_ID, expiresIn: '5m' },
     );
     res.json({ identity_token: identityToken });
   });
   ```

   `host_api/` in this repo does the same in Dart. The full rules are in the API reference,
   `https://app.davodesk.com/developers/api`, under Authentication.
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

   The identity function asks your endpoint from step 2 and returns its token, or `null`
   when no one is signed in. With the `http` package:

   ```dart
   Future<String?> fetchDavoDeskIdentityToken() async {
     final response = await http.get(
       Uri.parse('https://api.example.com/support/identity'),
       headers: {'authorization': 'Bearer $yourAppsSessionToken'},
     );
     if (response.statusCode != 200) return null;
     return (jsonDecode(response.body) as Map<String, Object?>)['identity_token']
         as String?;
   }
   ```

   It is called each time a session opens: at first use, a minute before the 30-minute
   session runs out, after a `401`, and when the app comes back to the foreground. Keep it
   cheap and return a fresh token each time.

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
DavoDesk, and use DavoDesk's own greys.

**Set in DavoDesk, with no code.** On the brand's **Chat look** page:

- the **logo**, in the chat's header and over the bot's replies (the brand's initial when
  there is none);
- the **header logo**, the wordmark on Home's coloured header;
- the **bot's name**, over its replies and as the chat's title ("DavoDesk AI" until one is
  set). The bot's replies show the logo and the name once per run, with ✦ on the replies
  DavoDesk AI wrote;
- the app's **colour** and **corners** (they can follow the website's);
- the **tagline** and the **notice** at the top of the chat, and **Home's links**.

A look saved in DavoDesk shows the next time support opens, with no new release of your
app. Support waits up to two seconds for it; on a slower network it opens with the last
look, and the new one shows the time after.

To make the screens match your app, pass a `DavoDeskTheme` to `DavoDesk.initialize`:

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

## Check that it works

1. Sign in as a test user and call `DavoDesk.show(context)`: Home opens under your brand's
   header.
2. Start a chat and ask a question: the bot answers under the brand's logo and the bot's
   name.
3. Ask for a person, or send the contact form: the ticket shows in DavoDesk, under that
   brand.
4. Change the bot's name on the Chat look page, close support and open it again: the new
   name shows.

## When something goes wrong

Listen to `DavoDesk.events` and log each `DavoDeskError`:

| Code | What it means |
|---|---|
| `TOKEN_FAILED` | Your identity function returned `null` or threw, or DavoDesk refused the token: a wrong or deleted key, a token not signed with HS256, an `exp` missing or more than an hour ahead, or a verified email that already belongs to another customer of the brand. The SDK keeps retrying and tells you once per run of refusals. |
| `CHANNEL_UNAVAILABLE` | The channel's settings could not be read, so support did not open: a wrong channel id, the channel turned off in DavoDesk, or no connection to `https://api.davodesk.com`. |

- **Help links do nothing on Android:** add the `<queries>` entry under Platform setup.
- **A new look does not show:** close support and open it again; on a slow network it
  shows the time after.

## Drawing your own screens

`DavoDeskClient` is what the screens use: the live conversation (`conversation`), the
tickets and the unread count, the contact form's `raiseTicket`, attachments, the help centre,
and `logout`. Create it once the app's binding is ready, call `start()`, and `dispose()` it
when done.

## Calling the API directly

Everything the SDK does goes through the public DavoDesk API, so an app may call it
directly instead. The API reference is at `https://app.davodesk.com/developers/api`.
