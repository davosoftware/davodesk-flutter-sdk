# Example app

A pretend company app ("Acme") for trying the DavoDesk Flutter SDK on a phone or an
emulator. It uses the SDK from `../davodesk_flutter` and gets its customers' identity
tokens from `../host_api`, as a real app gets them from its own server.

```bash
flutter run
```

To see the support screens in Acme's own look (its colours for light and dark, a heading
font and square corners, set with `DavoDeskTheme` in `lib/main.dart`):

```bash
flutter run --dart-define=ACME_LOOK=true
```
