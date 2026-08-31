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

  /// Resets bootstrap state for tests.
  @visibleForTesting
  static void resetForTests() {
    _initialized = false;
    _available = false;
    _initializationError = null;
  }
}
