/// Retention math for the Active/Archived → Deleted → permanently deleted path.
///
/// The persisted deletion timestamp is the source of truth. Device UI clocks
/// are only used to display remaining time and to evaluate eligibility.
abstract final class IncidentDeletionLifecycle {
  static const Duration retention = Duration(days: 30);

  static DateTime eligibilityAt(DateTime deletedAt) =>
      deletedAt.toUtc().add(retention);

  static bool isEligibleForPermanentDeletion({
    required DateTime deletedAt,
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    return !clock.isBefore(eligibilityAt(deletedAt));
  }

  /// Whole days remaining until eligibility, floored. Never negative.
  static int daysRemaining({required DateTime deletedAt, DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    final remaining = eligibilityAt(deletedAt).difference(clock).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whole days since [deletedAt], floored. Never negative.
  static int daysSinceDeleted({required DateTime deletedAt, DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    final elapsed = clock.difference(deletedAt.toUtc()).inDays;
    return elapsed < 0 ? 0 : elapsed;
  }

  static String deletedAgoLabel({required DateTime deletedAt, DateTime? now}) {
    final days = daysSinceDeleted(deletedAt: deletedAt, now: now);
    if (days == 0) {
      return 'Deleted today';
    }
    if (days == 1) {
      return 'Deleted 1 day ago';
    }
    return 'Deleted $days days ago';
  }

  static String permanentInLabel({required DateTime deletedAt, DateTime? now}) {
    final days = daysRemaining(deletedAt: deletedAt, now: now);
    if (days == 0) {
      return 'Permanently deleted today';
    }
    if (days == 1) {
      return 'Permanently deleted in 1 day';
    }
    return 'Permanently deleted in $days days';
  }
}
