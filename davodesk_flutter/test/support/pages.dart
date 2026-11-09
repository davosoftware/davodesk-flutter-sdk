/// Pumps an SDK page as the support routes host it, over a client of a [FakeApi].
library;

import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/ui/core/scope.dart';
import 'package:davodesk_flutter/src/ui/core/support_shell.dart';
import 'package:davodesk_flutter/src/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_api.dart';
import 'fakes.dart';

/// A page on screen, and what it asked for.
class PageHarness {
  PageHarness(this.client, this.api, this.sockets);

  /// The page's client.
  final DavoDeskClient client;

  /// The API behind it.
  final FakeApi api;

  /// The chat sockets it opened.
  final List<FakeSocket> sockets;

  /// Where the page led, in order.
  final went = <SupportPlace>[];

  /// The links it opened.
  final links = <Uri>[];

  /// Takes the page down and stops the client.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  }
}

/// Pumps [page] on a phone-sized screen at [textScale], over [api].
Future<PageHarness> pumpPage(
  WidgetTester tester,
  Widget Function() page, {
  FakeApi? api,
  double textScale = 1,
  void Function(DavoDeskClient client)? before,
  Future<UploadFile?> Function(AttachFrom from)? pickAttachment,
  DavoDeskEmailForm? emailForm,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final (:client, api: fake, :sockets, identities: _) = arrange(api: api);
  before?.call(client);
  final harness = PageHarness(client, fake, sockets);
  final config = await client.config();
  await tester.pumpWidget(
    MaterialApp(
      home: SupportScope(
        client: client,
        config: config,
        go: (_, place) => harness.went.add(place),
        pickAttachment: pickAttachment,
        emailForm: emailForm,
        openLink: (url) async {
          harness.links.add(url);
          return true;
        },
        child: Builder(
          builder: (context) => SupportShell(
            colors: SupportColors.resolve(context, config: config),
            child: page(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}
