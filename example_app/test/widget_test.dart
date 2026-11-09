import 'package:flutter_test/flutter_test.dart';

import 'package:davodesk_example/main.dart';

void main() {
  testWidgets('opens on the pretend company app', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Acme'), findsOneWidget);
  });
}
