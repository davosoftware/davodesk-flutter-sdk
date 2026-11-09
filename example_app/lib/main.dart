import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// A pretend company's app ("Acme") for trying the DavoDesk SDK. Signing in as a pretend
/// customer and the Help button come with the SDK.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acme',
      home: Scaffold(
        appBar: AppBar(title: const Text('Acme')),
        body: const Center(child: Text('The DavoDesk SDK is not wired in yet.')),
      ),
    );
  }
}
