enum PasswordStrength {
  empty,
  weak,
  fair,
  good,
  strong,
}

abstract final class PasswordStrengthEvaluator {
  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;

    final criteria = [
      password.length >= 8,
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'[0-9]').hasMatch(password),
      RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    ];

    final score = criteria.where((passed) => passed).length;

    return switch (score) {
      0 || 1 => PasswordStrength.weak,
      2 => PasswordStrength.fair,
      3 || 4 => PasswordStrength.good,
      _ => PasswordStrength.strong,
    };
  }

  static String label(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => 'Enter a password',
        PasswordStrength.weak => 'Weak',
        PasswordStrength.fair => 'Fair',
        PasswordStrength.good => 'Good',
        PasswordStrength.strong => 'Strong',
      };

  static double progress(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => 0,
        PasswordStrength.weak => 0.25,
        PasswordStrength.fair => 0.5,
        PasswordStrength.good => 0.75,
        PasswordStrength.strong => 1,
      };
}
