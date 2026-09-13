import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

/// Firebase initialization with graceful failure — app must not crash.
abstract final class FirebaseBootstrap {
  static bool _initialized = false;
  static bool _available = false;
  static Object? _initializationError;

  static bool get isInitialized => _initialized;
  static bool get isAvailable => _available;
  static Object? get initializationError => _initializationError;

  static Future<bool> initialize() async {
    if (_initialized) {
      return _available;
    }

    _initialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _available = true;

      await _activateAppCheck();

      try {
        await GoogleSignIn.instance.initialize();
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Google Sign-In initialization failed: $error');
        }
      }

      if (kDebugMode) {
        debugPrint('Firebase initialized successfully.');
      }
    } catch (error, stackTrace) {
      _available = false;
      _initializationError = error;
      if (kDebugMode) {
        debugPrint('Firebase initialization failed: $error');
        debugPrint('$stackTrace');
      }
    }

    return _available;
  }

  /// Client App Check tokens. Enforcement is a Firebase Console setting and
  /// is **not** verified here (REQUIRES DEVICE/CONSOLE VERIFICATION).
  /// Debug provider keeps local/emulator development working.
  static Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      if (kDebugMode) {
        debugPrint(
          'Firebase App Check client activated '
          '(enforcement is Console-only).',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase App Check activation skipped: $error');
      }
    }
  }

  /// Resets bootstrap state for tests.
  @visibleForTesting
  static void resetForTests() {
    _initialized = false;
    _available = false;
    _initializationError = null;
  }
}
