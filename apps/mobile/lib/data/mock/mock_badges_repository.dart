import '../models/badge.dart';
import '../repositories/auth_repository.dart';
import '../repositories/badges_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_badges.dart';
import 'mock_latency.dart';

class MockBadgesRepository implements BadgesRepository {
  final MockAuthRepository _auth;

  MockBadgesRepository(this._auth);

  String get _currentUserId => switch (_auth.currentState) {
        AuthSignedIn(:final user) => user.id,
        _ => 'user-moi-001',
      };

  @override
  Future<List<Badge>> listMyBadges() async {
    await MockLatency.mediumDelay();
    return mockBadges.where((b) => b.userId == _currentUserId).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  }

  @override
  Future<Badge?> getBadge(String badgeId) async {
    await MockLatency.shortDelay();
    return mockBadgesById[badgeId];
  }

  @override
  Future<String> getShareImageUrl(String badgeId) async {
    await MockLatency.simulate();
    final badge = mockBadgesById[badgeId];
    return badge?.composedBadgeUrl ??
        'https://placehold.co/1080x1920/0a0a0a/FF2D95?text=smwhr';
  }
}
