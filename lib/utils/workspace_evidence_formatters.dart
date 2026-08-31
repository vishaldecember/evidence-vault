import 'package:intl/intl.dart';

import 'instant_codec.dart';

/// Formatters for workspace Evidence Map presentation.
abstract final class WorkspaceEvidenceFormatters {
  static String lastPreserved(DateTime dateTime) {
    final local = InstantCodec.toLocal(dateTime);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return 'Today • ${DateFormat('HH:mm').format(local)}';
    }
    if (difference.inDays == 1) {
      return 'Yesterday • ${DateFormat('HH:mm').format(local)}';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago • ${DateFormat('HH:mm').format(local)}';
    }

    return DateFormat('d MMM yyyy • HH:mm').format(local);
  }

  /// Formats a preserved timestamp for [EvidenceArtifactCard].
  static String preservedTimestamp(DateTime dateTime) {
    final local = InstantCodec.toLocal(dateTime);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return 'Today • ${DateFormat('HH:mm').format(local)}';
    }
    if (difference.inDays == 1) {
      return 'Yesterday • ${DateFormat('HH:mm').format(local)}';
    }
    if (local.year == now.year) {
      return DateFormat('d MMM • HH:mm').format(local);
    }

    return DateFormat('d MMM yyyy • HH:mm').format(local);
  }

  /// Canonical evidence creation/preservation clock.
  ///
  /// UTC → local once. Calendar day in the device timezone. Always includes
  /// seconds. Inspector, vertical Workspace, and Investigation must use this
  /// for the same evidence instant.
  static String evidenceClock(DateTime dateTime, {DateTime? now}) {
    final local = InstantCodec.toLocal(dateTime);
    final localNow = InstantCodec.toLocal(now ?? DateTime.now());
    final time = DateFormat('HH:mm:ss').format(local);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final day = DateTime(local.year, local.month, local.day);
    final deltaDays = today.difference(day).inDays;

    if (deltaDays == 0) {
      return 'Today • $time';
    }
    if (deltaDays == 1) {
      return 'Yesterday • $time';
    }
    if (local.year == localNow.year) {
      return '${DateFormat('MMM d').format(local)} • $time';
    }
    return '${DateFormat('MMM d yyyy').format(local)} • $time';
  }

  /// Compact local wall-clock of the canonical evidence instant (`HH:mm:ss`).
  static String evidenceClockTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(InstantCodec.toLocal(dateTime));
  }

  /// Evidence Inspector capture/preservation clock — local time with seconds.
  static String inspectorTimestamp(DateTime dateTime, {DateTime? now}) {
    return evidenceClock(dateTime, now: now);
  }

  /// Description/context-note stamp, independent of evidence capture time.
  static String descriptionStamp(
    DateTime dateTime, {
    required bool updated,
    DateTime? now,
  }) {
    final local = InstantCodec.toLocal(dateTime);
    final localNow = InstantCodec.toLocal(now ?? DateTime.now());
    final time = DateFormat('HH:mm:ss').format(local);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final day = DateTime(local.year, local.month, local.day);
    final deltaDays = today.difference(day).inDays;
    final prefix = updated ? 'Updated' : 'Added';

    if (deltaDays == 0) {
      return '$prefix today at $time';
    }
    if (deltaDays == 1) {
      return '$prefix yesterday at $time';
    }
    if (local.year == localNow.year) {
      return '$prefix ${DateFormat('MMM d').format(local)} at $time';
    }
    return '$prefix ${DateFormat('MMM d yyyy').format(local)} at $time';
  }

  /// Immutable capture time for the Timeline Workspace — same instant as Inspector.
  static String timelineCaptureTime(DateTime dateTime, {DateTime? now}) {
    return evidenceClock(dateTime, now: now);
  }

  /// Formats when context was added — "Added today • 10:42".
  static String contextAdded(DateTime dateTime) {
    final local = InstantCodec.toLocal(dateTime);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final time = DateFormat('HH:mm').format(local);

    if (difference.inDays < 1) {
      return 'Added today • $time';
    }
    if (difference.inDays == 1) {
      return 'Added yesterday • $time';
    }
    if (local.year == now.year) {
      return 'Added ${DateFormat('d MMM').format(local)} • $time';
    }

    return 'Added ${DateFormat('d MMM yyyy').format(local)} • $time';
  }
}
