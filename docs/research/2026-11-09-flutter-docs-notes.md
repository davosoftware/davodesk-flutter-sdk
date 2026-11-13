# What current Flutter and Dart ask of this SDK

Read on 2026-11-09, before building the SDK (the owner asked). Flutter 3.47 / Dart 3.13 is the
current stable release, and the version installed here (3.47.5). Flutter 3.50 is announced as
tentative.

## What changes our plans

1. **Material and Cupertino are leaving the framework.**
   - Contributions to `package:flutter/material.dart` froze in 3.44.
   - `package:material_ui` and `package:cupertino_ui` 1.0 have been on pub.dev since 3.47; 1.10.0 is the latest.
   - 3.50 formally deprecates the framework copies, and a later release removes them.
   - The two are **different types**: a `material_ui` `ThemeData` is not a framework `ThemeData`.
   - `MaterialUiCompatibilityBridge` lets old Material code read a `material_ui` theme, but it can't fix public API types.

   **For us:**
   - The SDK uses `material_ui` from day one.
   - Its public calls expose no Material types.
   - It wraps its own pages in its own `Theme` and `Localizations`, so it works inside an app on either Material.
   - It can read an app's theme (brightness, font) only when the app also uses `material_ui`. Otherwise it follows the phone's light or dark setting, and `DavoDeskTheme(brightness:, fontFamily:)` lets the app say otherwise.
   - The floor becomes **Flutter 3.47 / Dart 3.13**.
2. **iOS uses Swift Package Manager by default** (since 3.44), and the CocoaPods registry becomes read-only on 2 December 2026.
   - Prefer plugins that support SPM: flutter.dev's `url_launcher`, `shared_preferences`, `image_picker` and `file_selector`.
   - That replaces `file_picker`, whose SPM support isn't stated.
   - Photos come through `image_picker` and documents (PDF) through `file_selector`.
3. **The layering Flutter recommends** (its architecture guidance and official agent skills):
   - services wrap the API, the socket and storage;
   - repositories hold state and the rules (session, conversation, tickets, unread);
   - each screen has a view model (`ChangeNotifier`) and a view built with `ListenableBuilder`.

   No state-management package is required; constructor injection is enough for an SDK.
4. **Dart 3.13 features to use:**
   - primary constructors, on by default since 3.13 (`class ChatOption(final String key, final String label);`);
   - dot shorthands (3.10);
   - null-aware elements (3.8);
   - sealed classes with exhaustive `switch`;
   - map patterns in `fromJson`.

   Formatting is the tall style, with trailing commas managed by `dart format`.
5. **Analysis:**
   - `flutter_lints` (`lints` for host_api), plus `strict-casts`, `strict-inference` and `strict-raw-types`;
   - run `dart fix --apply` and `dart format .` before each commit;
   - log with `package:logging` (`Logger('DavoDesk')`), never `print`.
6. **Accessibility:**
   - since 3.47, `Semantics(header: true)` does nothing on iOS and Android. Use `headingLevel: 1` and up for page titles;
   - text scales through `TextScaler`.
7. **Android:**
   - edge-to-edge is the default (since 3.27), so pages handle the system bars' insets themselves (`SafeArea`, `MediaQuery.paddingOf`);
   - the predictive back gesture is the default page transition (3.38). Use `PopScope` with `onPopInvokedWithResult`, never `WillPopScope`;
   - the example app sets `android:enableOnBackInvokedCallback="true"`.
8. **Colour:** `withValues(alpha:)` and `.a`, never `withOpacity` or `opacity`. Themes come from `ColorScheme.fromSeed`, and component themes take `*ThemeData` classes (`CardThemeData`, `DialogThemeData`).
9. **Widget previews are stable** (3.47). Each screen gets `@Preview` functions, light and dark, fed by fixture data. Previews run on the web, so no `dart:io`, and asset paths are package paths.
10. **Avoid:**
    - the old `Radio` API (redesigned in 3.35); use `SegmentedButton` for Good/Bad;
    - `DropdownButtonFormField.value` (use `initialValue`);
    - `describeEnum` (removed in 3.47);
    - SnackBars with actions, which no longer dismiss themselves (3.38).
11. **Layout:**
    - `ListView.builder` for lists;
    - content constrained to about 640 px wide on large screens;
    - no orientation lock;
    - decisions by window size (`MediaQuery.sizeOf`, `LayoutBuilder`), never by device type.
12. **Tests:**
    - `flutter_test` widget tests;
    - `http`'s `MockClient` and hand-written fakes, with no `mockito` or `build_runner`, so the package stays free of generated code;
    - `fake_async` for timers;
    - one widget test that hosts the SDK's pages inside a framework-Material app, to prove the wrapper works for apps that haven't migrated.

## Checked again 2026-11-13 (Chat look)

Flutter 3.50 shipped on 2026-11-11. The framework's bundled Material library is now
formally deprecated (this SDK already uses `material_ui`); the other changes are the order
of `WidgetSpan`s in right-to-left text, soft hyphens, and Android and web build flags.
None of it changes the SDK. Installed here: Flutter 3.47.5; the floor stays Flutter 3.47 /
Dart 3.13.

## Sources

- [Release notes](https://docs.flutter.dev/release/release-notes)
- [What's new in the docs](https://docs.flutter.dev/release/whats-new)
- [Breaking changes and migration guides](https://docs.flutter.dev/release/breaking-changes)
- [Migrate to standalone material_ui and cupertino_ui packages](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui)
- [Material and Cupertino decoupling are here](https://flutter.dev/blog/decoupling-material-cupertino)
- [material_ui on pub.dev](https://pub.dev/packages/material_ui)
- [Swift Package Manager for plugin authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)
- [Wide gamut Color](https://docs.flutter.dev/release/breaking-changes/wide-gamut-framework)
- [Semantics header and headingLevel](https://docs.flutter.dev/release/breaking-changes/semantics-header-heading-level)
- [Android predictive back](https://docs.flutter.dev/platform-integration/android/predictive-back)
- [What's new in Dart](https://dart.dev/resources/whats-new)
- [Flutter's official agent skills](https://github.com/flutter/agent-plugins): architecture, HTTP, JSON, widget tests, widget previews, responsive layout, static analysis, documentation, primary constructors.
