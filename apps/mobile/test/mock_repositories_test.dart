// Sesión 2 — fast unit tests over the mock repo infrastructure.
//
// Pure Dart, no widget runtime. Hive runs against a temp directory.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// `hive` is re-exported by hive_flutter; importing it directly keeps the
// test off the Flutter-platform plugin path that needs path_provider.
// ignore: depend_on_referenced_packages
import 'package:hive/hive.dart';

import 'package:smwhr/data/mock/mock_auth_repository.dart';
import 'package:smwhr/data/mock/mock_badges_repository.dart';
import 'package:smwhr/data/mock/mock_events_repository.dart';
import 'package:smwhr/data/repositories/auth_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('smwhr_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MockAuthRepository', () {
    test('starts signed out with a fresh Hive box', () async {
      final repo = await MockAuthRepository.create();
      expect(repo.currentState, isA<AuthSignedOut>());
    });

    test('signInWithApple persists the session across restarts', () async {
      final first = await MockAuthRepository.create();
      final result = await first.signInWithApple();
      expect(result, isA<AuthResultReady>());
      expect(first.currentState, isA<AuthSignedIn>());

      await Hive.close();
      Hive.init(tempDir.path);

      final second = await MockAuthRepository.create();
      expect(second.currentState, isA<AuthSignedIn>(),
          reason: 'cold restart should rehydrate the persisted session');
    });

    test('checkHandleAvailable rejects reserved + taken handles', () async {
      final repo = await MockAuthRepository.create();
      expect(await repo.checkHandleAvailable('admin'), isFalse);
      expect(await repo.checkHandleAvailable('moi'), isFalse);
      expect(await repo.checkHandleAvailable('sofia'), isFalse);
      expect(await repo.checkHandleAvailable('available_handle'), isTrue);
    });
  });

  group('MockEventsRepository', () {
    test('listFeatured returns the 3 BTS nights in chronological order',
        () async {
      final auth = await MockAuthRepository.create();
      final repo = MockEventsRepository(auth);
      final featured = await repo.listFeatured();
      expect(featured.length, 3);
      expect(featured.map((e) => e.id), [
        'evt-bts-mx-n1',
        'evt-bts-mx-n2',
        'evt-bts-mx-n3',
      ]);
    });

    test('setIntent / removeIntent toggles hasIntent state', () async {
      final auth = await MockAuthRepository.create();
      await auth.signInWithApple();
      final repo = MockEventsRepository(auth);
      const id = 'evt-bad-bunny-cdmx';
      expect(await repo.hasIntent(id), isFalse);
      await repo.setIntent(id);
      expect(await repo.hasIntent(id), isTrue);
      await repo.removeIntent(id);
      expect(await repo.hasIntent(id), isFalse);
    });
  });

  group('MockBadgesRepository', () {
    test("lists @moi's 7 badges sorted by event date desc", () async {
      final auth = await MockAuthRepository.create();
      await auth.signInWithApple();
      final repo = MockBadgesRepository(auth);
      final badges = await repo.listMyBadges();
      expect(badges.length, 7);
      for (var i = 0; i + 1 < badges.length; i++) {
        expect(
          badges[i].eventDate.isAfter(badges[i + 1].eventDate) ||
              badges[i].eventDate.isAtSameMomentAs(badges[i + 1].eventDate),
          isTrue,
          reason: 'badges must be sorted by eventDate desc',
        );
      }
    });

    test('serialLabel renders padded #serial / total', () async {
      final auth = await MockAuthRepository.create();
      await auth.signInWithApple();
      final repo = MockBadgesRepository(auth);
      final badge = await repo.getBadge('bdg-001');
      expect(badge, isNotNull);
      expect(badge!.serialLabel, '#0412 / 28412');
    });
  });
}
