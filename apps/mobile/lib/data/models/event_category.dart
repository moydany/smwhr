/// Verticals supported in R0.1+.
///
/// Order matters — `EventCategory.values` is what the Interests screen
/// (Pantalla 03) iterates to render the 5 chips.
enum EventCategory {
  music,
  sports,
  festivals,
  outdoor,
  culture;

  /// Human label shown in UI (es-MX default; i18n is a Phase 2 concern).
  String get label => switch (this) {
        EventCategory.music => 'Música',
        EventCategory.sports => 'Deportes',
        EventCategory.festivals => 'Festivales',
        EventCategory.outdoor => 'Outdoor',
        EventCategory.culture => 'Cultura',
      };

  /// Slug used in API + analytics.
  String get slug => name;

  static EventCategory? fromSlug(String slug) {
    for (final c in EventCategory.values) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}
