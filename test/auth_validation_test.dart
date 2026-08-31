import 'package:flutter_test/flutter_test.dart';
import 'package:evidence_vault/utils/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('returns error for empty email', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email(null), isNotNull);
    });

    test('returns error for invalid email', () {
      expect(AuthValidators.email('not-an-email'), isNotNull);
    });

    test('returns null for valid email', () {
      expect(AuthValidators.email('john@email.com'), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('returns error for empty password', () {
      expect(AuthValidators.password(''), isNotNull);
    });

    test('returns error when criteria are missing', () {
      expect(AuthValidators.password('short'), isNotNull);
      expect(AuthValidators.password('alllowercase1!'), isNotNull);
      expect(AuthValidators.password('ALLUPPERCASE1!'), isNotNull);
      expect(AuthValidators.password('NoNumbers!'), isNotNull);
      expect(AuthValidators.password('NoSpecial1'), isNotNull);
    });

    test('returns null for strong password', () {
      expect(AuthValidators.password('SecurePass1!'), isNull);
    });
  });

  group('AuthValidators.confirmPassword', () {
    test('returns error when passwords do not match', () {
      expect(
        AuthValidators.confirmPassword('Different1!', 'SecurePass1!'),
        isNotNull,
      );
    });

    test('returns null when passwords match', () {
      expect(
        AuthValidators.confirmPassword('SecurePass1!', 'SecurePass1!'),
        isNull,
      );
    });
  });
}
