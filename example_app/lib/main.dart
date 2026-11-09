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

/// DavoDesk for Acme, with an email form asking for an order number; the screens take
/// the channel's accent.
Future<void> startDavoDesk({
  required String channelId,
  required String apiUrl,
  required Future<String?> Function() identityToken,
}) => DavoDesk.initialize(
  channelId: channelId,
  apiUrl: apiUrl,
  identityToken: identityToken,
  emailForm: const DavoDeskEmailForm(
    note: 'We typically respond to all email inquiries within 24 hours.',
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
