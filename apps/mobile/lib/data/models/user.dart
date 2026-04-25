/// Domain model for a smwhr user.
///
/// Mirrors `GET /me` and `GET /users/:handle` API responses. Hive adapters
/// for offline cache live in `lib/data/local/models/` (Session 7+).
class User {
  final String id;
  final String handle;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String city;
  final String countryCode;
  final List<String> interests; // EventCategory.slug values
  final String language; // 'es' | 'en'
  final DateTime? onboardingCompletedAt;
  final DateTime createdAt;

  // Public stats (visible on profile)
  final int questsCount;
  final int venuesCount;
  final int artistsCount;

  const User({
    required this.id,
    required this.handle,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.bio,
    required this.city,
    required this.countryCode,
    required this.interests,
    required this.language,
    this.onboardingCompletedAt,
    required this.createdAt,
    this.questsCount = 0,
    this.venuesCount = 0,
    this.artistsCount = 0,
  });

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  User copyWith({
    String? handle,
    String? displayName,
    String? bio,
    String? city,
    String? countryCode,
    List<String>? interests,
    String? language,
    DateTime? onboardingCompletedAt,
    int? questsCount,
    int? venuesCount,
    int? artistsCount,
  }) {
    return User(
      id: id,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      email: email,
      avatarUrl: avatarUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
      interests: interests ?? this.interests,
      language: language ?? this.language,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      createdAt: createdAt,
      questsCount: questsCount ?? this.questsCount,
      venuesCount: venuesCount ?? this.venuesCount,
      artistsCount: artistsCount ?? this.artistsCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is User && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Auth session persisted in Hive across cold starts.
class AuthSession {
  final String userId;
  final String accessToken;
  final String? refreshToken;
  final DateTime issuedAt;
  final DateTime? expiresAt;

  const AuthSession({
    required this.userId,
    required this.accessToken,
    this.refreshToken,
    required this.issuedAt,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<dynamic, dynamic> json) => AuthSession(
        userId: json['userId'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
      );
}
