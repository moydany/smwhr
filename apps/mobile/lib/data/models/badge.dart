import 'event_category.dart';

/// Domain model for a verified attendance badge.
///
/// Mirrors `GET /badges/:id`. `serial` is the deterministic serial number
/// rendered on the badge ("#0001/∞" until R0.3 caps issuance).
class Badge {
  final String id;
  final String eventId;
  final String userId;

  // Display metadata duplicated from event for offline-first reads.
  final String eventTitle;
  final String? artistName;
  final String venueName;
  final String city;
  final String countryCode;
  final DateTime eventDate;
  final EventCategory category;

  // Capture
  final String? capturedPhotoUrl;
  final String? composedBadgeUrl; // photo + frame composited
  final String frameUrl;

  // Identity
  final int serial; // 1-based
  final int? totalIssued; // null while issuance is open

  // Verification
  final double verificationScore; // 0..1
  final DateTime issuedAt;

  const Badge({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.eventTitle,
    this.artistName,
    required this.venueName,
    required this.city,
    required this.countryCode,
    required this.eventDate,
    required this.category,
    this.capturedPhotoUrl,
    this.composedBadgeUrl,
    required this.frameUrl,
    required this.serial,
    this.totalIssued,
    required this.verificationScore,
    required this.issuedAt,
  });

  /// Stable display string: "#0001 / ∞" or "#0001 / 0420".
  String get serialLabel {
    final s = serial.toString().padLeft(4, '0');
    final t = totalIssued?.toString().padLeft(4, '0') ?? '∞';
    return '#$s / $t';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Badge && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
