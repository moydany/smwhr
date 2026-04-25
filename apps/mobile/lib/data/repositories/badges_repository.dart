import '../models/badge.dart';

abstract class BadgesRepository {
  Future<List<Badge>> listMyBadges();
  Future<Badge?> getBadge(String badgeId);

  /// Returns a 1080x1920 ready-to-share image URL (or local file path in
  /// mock mode). Generated server-side in Phase 2.
  Future<String> getShareImageUrl(String badgeId);
}
