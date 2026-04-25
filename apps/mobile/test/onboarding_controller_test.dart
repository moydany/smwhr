// Sesión 4 — controller-level tests for the onboarding flow.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:hive/hive.dart';

import 'package:smwhr/data/providers.dart';
import 'package:smwhr/features/onboarding/state/onboarding_state.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('smwhr_onboarding_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Keep the autoDispose provider alive for the lifetime of the test.
    final sub = c.listen(onboardingControllerProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  test('handle moves through checking → invalid → available', () async {
    final c = makeContainer();
    await c.read(mockAuthRepositoryProvider.future);
    final ctrl = c.read(onboardingControllerProvider.notifier);

    // Reserved handle from mock_users.dart
    ctrl.setHandle('admin');
    // 'admin' is locally valid (5 chars, alnum, no underscore start), so
    // starts as "checking" then goes to "taken" after the debounce.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(c.read(onboardingControllerProvider).handleStatus,
        HandleStatus.taken);

    // Locally invalid (too short) — synchronous response
    ctrl.setHandle('a');
    expect(c.read(onboardingControllerProvider).handleStatus,
        HandleStatus.invalid);

    // Available
    ctrl.setHandle('completely_new');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(c.read(onboardingControllerProvider).handleStatus,
        HandleStatus.available);
  });

  test('toggleEverything selects all five categories then clears', () {
    final c = makeContainer();
    final ctrl = c.read(onboardingControllerProvider.notifier);
    ctrl.toggleEverything();
    expect(c.read(onboardingControllerProvider).interests.length, 5);
    ctrl.toggleEverything();
    expect(c.read(onboardingControllerProvider).interests, isEmpty);
  });

  test('identityReady gates Continue button on Identity screen', () async {
    final c = makeContainer();
    await c.read(mockAuthRepositoryProvider.future);
    final ctrl = c.read(onboardingControllerProvider.notifier);

    ctrl.setHandle('completely_new');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    ctrl.setDisplayName('M');
    expect(c.read(onboardingControllerProvider).identityReady, isFalse,
        reason: 'displayName too short');

    ctrl.setDisplayName('Moi');
    expect(c.read(onboardingControllerProvider).identityReady, isTrue);
  });

  test('submit hits AuthRepository.completeOnboarding and returns true',
      () async {
    final c = makeContainer();
    await c.read(mockAuthRepositoryProvider.future);
    final ctrl = c.read(onboardingControllerProvider.notifier);

    ctrl.setHandle('newuser');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    ctrl.setDisplayName('New User');
    ctrl.setCity('CDMX');
    ctrl.toggleInterest('music');

    final ok = await ctrl.submit();
    expect(ok, isTrue);
    expect(c.read(onboardingControllerProvider).submitError, isNull);
  });
}
