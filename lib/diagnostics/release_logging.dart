import 'package:flutter/foundation.dart';

import 'release_log_sanitizer.dart';

/// Installs release-only redaction of [debugPrint].
///
/// Does not disable operational logs. Debug and profile are unchanged.
void installReleaseLogRedaction() {
  if (!kReleaseMode) {
    return;
  }
  final previous = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    final sanitized = ReleaseLogSanitizer.sanitize(message);
    if (sanitized == null || sanitized.isEmpty) {
      return;
    }
    previous(sanitized, wrapWidth: wrapWidth);
  };
}
