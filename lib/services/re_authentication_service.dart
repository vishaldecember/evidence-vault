import 'package:local_auth/local_auth.dart';

import '../utils/auth_validators.dart';
import 'auth_service.dart';
import 'user_session_service.dart';

class ReAuthenticationException implements Exception {
  const ReAuthenticationException(this.message);

  final String message;
}

/// Biometric or password re-authentication for destructive account actions.
abstract final class ReAuthenticationService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<void> reauthenticate({String? password}) async {
    if (!UserSessionService.isSignedIn) {
      throw const ReAuthenticationException(
        'You must be signed in to continue.',
      );
    }

    if (password != null && password.isNotEmpty) {
      await _reauthenticateWithPassword(password);
      return;
    }

    final canUseBiometrics = await _canUseBiometrics();
    if (canUseBiometrics) {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to delete your account.',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (authenticated) {
        return;
      }
    }

    throw const ReAuthenticationException(
      'Password confirmation is required to continue.',
    );
  }

  static Future<bool> canUseBiometrics() => _canUseBiometrics();

  static Future<void> _reauthenticateWithPassword(String password) async {
    final email = UserSessionService.account?.email;
    if (email == null) {
      throw const ReAuthenticationException(
        'Unable to verify your account.',
      );
    }

    if (AuthValidators.signInPassword(password) != null) {
      throw const ReAuthenticationException(
        'Enter your current password to continue.',
      );
    }

    await AuthService.reauthenticate(email: email, password: password);
  }

  static Future<bool> _canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return false;
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      return canCheck && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
