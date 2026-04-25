// Sesión 3 — widget tests for shared button + text field + progress dots.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smwhr/core/theme/app_theme.dart';
import 'package:smwhr/shared/widgets/smwhr_button.dart';
import 'package:smwhr/shared/widgets/smwhr_progress_dots.dart';
import 'package:smwhr/shared/widgets/smwhr_text_field.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      );

  group('SmwhrButton', () {
    testWidgets('renders label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        SmwhrButton(
          label: 'Continuar',
          onPressed: () => taps++,
          haptic: null, // no haptic in tests
        ),
      ));
      expect(find.text('Continuar'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      expect(taps, 1);
    });

    testWidgets('disables when onPressed is null', (tester) async {
      await tester.pumpWidget(wrap(
        const SmwhrButton(
          label: 'Disabled',
          onPressed: null,
        ),
      ));
      // GestureDetector with null onTap is hit-testable but no-op; verify
      // the AnimatedOpacity dims to 0.6 by reading the widget tree.
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets('shows spinner instead of label when isLoading', (tester) async {
      await tester.pumpWidget(wrap(
        SmwhrButton(
          label: 'Loading',
          isLoading: true,
          onPressed: () {},
          haptic: null,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('renders leading icon next to label', (tester) async {
      await tester.pumpWidget(wrap(
        SmwhrButton(
          label: 'Apple',
          leading: const Icon(Icons.apple),
          onPressed: () {},
          haptic: null,
        ),
      ));
      expect(find.byIcon(Icons.apple), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });
  });

  group('SmwhrTextField', () {
    testWidgets('renders label, hint, and helper', (tester) async {
      await tester.pumpWidget(wrap(
        const SmwhrTextField(
          label: 'Handle',
          hint: '@yourhandle',
          helperText: 'Letters, numbers, _ only',
        ),
      ));
      expect(find.text('HANDLE'), findsOneWidget);
      expect(find.text('@yourhandle'), findsOneWidget);
      expect(find.text('Letters, numbers, _ only'), findsOneWidget);
    });

    testWidgets('shows errorText instead of helper when provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        const SmwhrTextField(
          label: 'Handle',
          helperText: 'optional',
          errorText: 'Already taken',
        ),
      ));
      expect(find.text('Already taken'), findsOneWidget);
      expect(find.text('optional'), findsNothing);
    });

    testWidgets('shows check icon when isValid', (tester) async {
      await tester.pumpWidget(wrap(
        const SmwhrTextField(
          label: 'Handle',
          isValid: true,
        ),
      ));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('SmwhrProgressDots', () {
    testWidgets('renders the right number of dots', (tester) async {
      await tester.pumpWidget(wrap(
        const SmwhrProgressDots(total: 3, current: 2),
      ));
      // Each dot is an AnimatedContainer; the row also contains gap
      // SizedBoxes. We assert via finder count.
      final dots = find.byType(AnimatedContainer);
      expect(dots, findsNWidgets(3));
    });
  });
}
