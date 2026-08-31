import '../diagnostics/sprint6c_file_trace.dart';
import '../models/user_account.dart';

/// Active user session — preserved during Clear Vault, removed on Delete Account.
abstract final class UserSessionService {
  static UserAccount? _account;
  static String? _sessionToken;
  static int _sessionVersion = 0;

  static UserAccount? get account => _account;
  static bool get isSignedIn => _account != null;
  static String? get sessionToken => _sessionToken;
  static int get sessionVersion => _sessionVersion;

  static void establishSession({
    required String email,
    required String name,
    String? userId,
  }) {
    Sprint6cFileTrace.session(
      'UserSession establishSession uid=${userId ?? email.toLowerCase()} '
      'wasSignedIn=${_account != null}',
    );
    _sessionVersion += 1;
    _sessionToken = 'session-${DateTime.now().millisecondsSinceEpoch}';
    _account = UserAccount(
      userId: userId ?? email.toLowerCase(),
      name: name,
      email: email,
    );
  }

  static void signOut() {
    Sprint6cFileTrace.session(
      'UserSession signOut wasUid=${_account?.userId ?? 'none'}',
    );
    _account = null;
    _invalidateSession();
  }

  static void deleteAccount() {
    Sprint6cFileTrace.session('UserSession deleteAccount');
    _account = null;
    _invalidateSession();
  }

  static void _invalidateSession() {
    _sessionToken = null;
    _sessionVersion += 1;
  }

  static void resetForTests() {
    _account = null;
    _sessionToken = null;
    _sessionVersion = 0;
  }
}
