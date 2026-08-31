/// Canonical Instant (UTC) encode/decode for evidence timestamps.
///
/// Store UTC. Convert to local only at presentation time, and only once.
abstract final class InstantCodec {
  /// UTC ISO-8601 with an explicit `Z` (or numeric offset).
  static String encode(DateTime value) => value.toUtc().toIso8601String();

  /// Parses [value] to a UTC instant without changing the historical moment.
  ///
  /// - Timezone-aware strings (`Z` / offset) → UTC.
  /// - Naive ISO strings (legacy local wall-clock) → treated as local, then UTC.
  /// - Firestore Timestamp `seconds` / epoch millis → UTC.
  /// - [DateTime] → UTC of the same instant.
  static DateTime? decode(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) {
        return null;
      }
      return parsed.toUtc();
    }
    try {
      final seconds = (value as dynamic).seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        );
      }
    } catch (_) {}
    try {
      final millis = (value as dynamic).millisecondsSinceEpoch as int?;
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
    } catch (_) {}
    return null;
  }

  /// Presentation conversion — identity when [value] is already local.
  static DateTime toLocal(DateTime value) => value.toLocal();
}
