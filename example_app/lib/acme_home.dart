import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'main.dart';
import 'sign_in.dart';

/// Acme's home once a customer signs in: the ways into DavoDesk support.
class AcmeHome extends StatelessWidget {
  /// Creates the home for the customer called [name].
  const AcmeHome({
    super.key,
    required this.name,
    required this.httpClient,
    required this.startSupport,
  });

  /// The customer's name.
  final String name;

  /// Talks to the host API, for signing in again.
  final http.Client httpClient;

  /// Sets DavoDesk up, for signing in again.
  final StartSupport startSupport;

  Future<void> _signOut(BuildContext context) async {
    await DavoDesk.logout();
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            SignInPage(httpClient: httpClient, startSupport: startSupport),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = name.split(' ').first;
    return Scaffold(
      appBar: AppBar(title: const Text('Acme')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Hi $first', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            ValueListenableBuilder<int>(
              valueListenable: DavoDesk.unread,
              builder: (context, unread, _) => FilledButton.icon(
                onPressed: () => DavoDesk.show(context),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.support_agent),
                ),
                label: const Text('Help'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => DavoDesk.ask(context, 'Where is my order?'),
              child: const Text('Ask about my order'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  DavoDesk.show(context, page: DavoDeskPage.contact),
              child: const Text('Send us a message'),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => _signOut(context),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
