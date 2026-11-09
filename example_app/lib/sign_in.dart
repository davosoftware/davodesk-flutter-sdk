import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'acme_home.dart';
import 'host_api.dart';
import 'main.dart';
import 'settings.dart';

/// Acme's sign-in: one of the host API's pretend customers.
class SignInPage extends StatefulWidget {
  /// Creates the page.
  const SignInPage({
    super.key,
    required this.httpClient,
    required this.startSupport,
  });

  /// Talks to the host API.
  final http.Client httpClient;

  /// Sets DavoDesk up for the signed-in customer.
  final StartSupport startSupport;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _settings = HostSettings();
  final _address = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _settings.load().then((address) {
      if (mounted) _address.text = address;
    });
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _signIn(String customer) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final address = _address.text.trim();
    final host = HostApi(Uri.parse(address), widget.httpClient);
    try {
      await _settings.save(address);
      final login = await host.login(customer);
      final config = await host.appConfig();
      await widget.startSupport(
        channelId: config.channelId,
        apiUrl: config.apiUrl,
        identityToken: () => host.identityToken(login.token),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AcmeHome(
            name: login.name,
            httpClient: widget.httpClient,
            startSupport: widget.startSupport,
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() => _error = 'Couldn’t reach the host API at $address.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acme')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Sign in as', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final (customer, name) in const [
            ('ada', 'Ada Lovelace'),
            ('ben', 'Ben Okafor'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: _busy ? null : () => _signIn(customer),
                child: Text(name),
              ),
            ),
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _address,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Host API',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}
