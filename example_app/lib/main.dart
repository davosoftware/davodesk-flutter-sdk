import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'sign_in.dart';

/// Sets DavoDesk up for a signed-in customer.
typedef StartSupport = Future<void> Function({
  required String channelId,
  required String apiUrl,
  required Future<String?> Function() identityToken,
});

/// Acme's own look for the support screens, shown when built with
/// `--dart-define=ACME_LOOK=true`.
const acmeLook = DavoDeskTheme(
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
  // Android's own serif, so the example needs no font files.
  headingFontFamily: 'serif',
  corners: DavoDeskCorners.square,
);

/// DavoDesk for Acme, with a contact form asking for an order number; the screens take
/// the channel's accent, or Acme's own look.
Future<void> startDavoDesk({
  required String channelId,
  required String apiUrl,
  required Future<String?> Function() identityToken,
}) => DavoDesk.initialize(
  channelId: channelId,
  apiUrl: apiUrl,
  identityToken: identityToken,
  theme: const bool.fromEnvironment('ACME_LOOK') ? acmeLook : null,
  contactForm: const DavoDeskContactForm(
    note: 'We typically respond within 24 hours.',
    extraField: DavoDeskFormField(label: 'Order ID', hint: 'e.g. #VP-8291'),
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AcmeApp(httpClient: http.Client()));
}

/// A pretend company's app ("Acme") for trying the DavoDesk SDK: sign in as a pretend
/// customer, then open support.
class AcmeApp extends StatelessWidget {
  /// Creates the app; [startSupport] sets DavoDesk up (tests pass their own).
  const AcmeApp({
    super.key,
    required this.httpClient,
    this.startSupport = startDavoDesk,
  });

  /// Talks to the host API.
  final http.Client httpClient;

  /// Sets DavoDesk up for the signed-in customer.
  final StartSupport startSupport;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Acme',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1E5AF0)),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF1E5AF0),
      brightness: Brightness.dark,
    ),
    home: SignInPage(httpClient: httpClient, startSupport: startSupport),
  );
}
