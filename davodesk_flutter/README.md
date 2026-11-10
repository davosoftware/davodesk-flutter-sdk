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
   DavoDesk.show(context, page: DavoDeskPage.messages);   // or .help, .contact
   DavoDesk.ask(context, 'Where is my order?');           // a conversation, asked
   DavoDesk.openTicket(context, ticketId);                // e.g. from a push notification
   ```

5. **Show the unread count** with `DavoDesk.unread` (a `ValueListenable<int>`), and
   listen to `DavoDesk.events` for opened, closed, unread, a raised ticket, and errors
   (`DavoDeskError('TOKEN_FAILED', …)` when your identity function gives no usable token).
6. **Log out** with `await DavoDesk.logout()` when the user signs out: it closes support,
   ends the session and forgets the user on the device.

## The look

The screens follow your app's light or dark setting (the phone's, when your app uses the
framework's Material rather than `material_ui`), use the channel's accent colour, and run
on your app's navigator as full-screen pages. `DavoDeskTheme` overrides the accent, the
brightness or the font.

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
