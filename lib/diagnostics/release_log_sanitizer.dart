/// Redacts secrets and evidence metadata from log lines.
///
/// Applied to [debugPrint] in release builds. Debug/profile keep full traces.
abstract final class ReleaseLogSanitizer {
  static final _url = RegExp(r'https?://[^\s]+', caseSensitive: false);
  static final _bearer = RegExp(r'Bearer\s+\S+', caseSensitive: false);
  static final _email = RegExp(
    r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final _assigned = RegExp(
    r'\b(uid|user|userId|title|path|storagePath|uri|downloadUrl|'
    r'token|accessToken|idToken|refreshToken|password|sha256|'
    r'latitude|longitude|fileName)\s*[:=]\s*[^\s,|]+',
    caseSensitive: false,
  );

  static String? sanitize(String? message) {
    if (message == null || message.isEmpty) {
      return message;
    }
    var out = message;
    out = out.replaceAll(_url, '[redacted-url]');
    out = out.replaceAll(_bearer, 'Bearer [redacted]');
    out = out.replaceAllMapped(_assigned, (match) {
      return '${match[1]}=[redacted]';
    });
    out = out.replaceAll(_email, '[redacted-email]');
    return out;
  }
}
