// apps/mobile/test/quest_history_screen_test.dart
//
// Renders QuestHistoryScreen with a stubbed repo emitting one entry
// per MyQuestStatus and asserts each pill label appears. Doesn't
// exercise navigation — the tap → route mapping is covered by inline
// inspection of the row's onTap closure.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:smwhr/data/models/event.dart';
import 'package:smwhr/data/models/event_category.dart';
import 'package:smwhr/data/models/quest.dart';
import 'package:smwhr/data/providers.dart';
import 'package:smwhr/data/repositories/quests_repository.dart';
import 'package:smwhr/features/profile/screens/quest_history_screen.dart';

class _StubRepo implements QuestsRepository {
  final List<MyQuestEntry> entries;
  _StubRepo(this.entries);

  @override
  Future<List<MyQuestEntry>> listMyQuests() async => entries;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Event _event(String slug, DateTime starts) => Event(
      id: slug,
      slug: slug,
      title: 'Title $slug',
      artistName: null,
      venueName: 'Venue',
      city: 'CDMX',
      countryCode: 'MX',
      startsAt: starts,
      endsAt: starts.add(const Duration(hours: 3)),
      description: '',
      category: EventCategory.music,
      geofencePolygon: const [],
    );

void main() {
  testWidgets('renders one row per status with the right pill', (tester) async {
    final now = DateTime.now();
    final entries = [
      MyQuestEntry(
        event: _event('verified', now.subtract(const Duration(days: 1))),
        intentCreatedAt: now,
        phase: QuestPhase.post,
        status: MyQuestStatus.verified,
        badge: BadgeSummary(
          id: 'b1',
          serialNumber: 1,
          awardedAt: now,
        ),
        verification: const QuestVerification(
          isVerified: true,
          verificationScore: 90,
        ),
      ),
      MyQuestEntry(
        event: _event('live', now),
        intentCreatedAt: now,
        phase: QuestPhase.during,
        status: MyQuestStatus.live,
      ),
      MyQuestEntry(
        event: _event('upcoming', now.add(const Duration(days: 7))),
        intentCreatedAt: now,
        phase: QuestPhase.pre,
        status: MyQuestStatus.upcoming,
      ),
      MyQuestEntry(
        event: _event('unverified', now.subtract(const Duration(days: 30))),
        intentCreatedAt: now.subtract(const Duration(days: 31)),
        phase: QuestPhase.post,
        status: MyQuestStatus.unverified,
      ),
    ];

    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const QuestHistoryScreen(),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsRepositoryProvider.overrideWithValue(_StubRepo(entries)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // Pump twice: first frame shows the loading spinner, second frame
    // surfaces the resolved data after the FutureProvider settles.
    await tester.pump();
    await tester.pump();

    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('PRÓXIMO'), findsOneWidget);
    expect(find.text('SIN VERIFICAR'), findsOneWidget);
  });
}
