// Sesión 1 smoke test: verifica que la app boota y renderiza el wordmark.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smwhr/main.dart';

void main() {
  testWidgets('SmwhrApp boots and renders the smwhr wordmark',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmwhrApp()));
    await tester.pump();

    expect(find.text('smwhr'), findsOneWidget);
    expect(find.text('YOU WERE SOMEWHERE'), findsOneWidget);
  });
}
