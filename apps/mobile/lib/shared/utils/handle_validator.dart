/// Pure validation for smwhr handles.
///
/// Rules (mirrors the backend that lands in Phase 2 — keep in sync):
/// - Length: 3..20 characters.
/// - Allowed: `a-z`, `0-9`, `_`. Lowercase only (we autolower in the field).
/// - Must start with a letter or digit (no leading underscore).
/// - Cannot be a reserved name (admin / smwhr / etc.) — owned by
///   `mock_users.dart`'s reservedHandles list.
///
/// Returns null when valid; otherwise a human-readable error.
class HandleValidator {
  HandleValidator._();

  static const int minLength = 3;
  static const int maxLength = 20;

  static final RegExp _allowed = RegExp(r'^[a-z0-9_]+$');
  static final RegExp _startsWithAlnum = RegExp(r'^[a-z0-9]');

  /// Cheap synchronous checks. Returns null when the handle passes the
  /// local rules; the live "is it taken" check happens via repository.
  static String? localError(String raw) {
    final h = raw.trim().toLowerCase();
    if (h.isEmpty) return null; // don't surface errors for empty input
    if (h.length < minLength) {
      return 'Mínimo $minLength caracteres.';
    }
    if (h.length > maxLength) {
      return 'Máximo $maxLength caracteres.';
    }
    if (!_startsWithAlnum.hasMatch(h)) {
      return 'Empieza con una letra o número.';
    }
    if (!_allowed.hasMatch(h)) {
      return 'Solo letras minúsculas, números y guion bajo.';
    }
    return null;
  }

  /// Normalises user input on the fly: lowercase, strip leading "@", strip
  /// spaces. Used by the text field's `onChanged` so the value the
  /// repository sees is always canonical.
  static String normalize(String raw) {
    var v = raw.trim().toLowerCase();
    if (v.startsWith('@')) v = v.substring(1);
    return v.replaceAll(' ', '');
  }
}
