import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum PasswordStrength {
  empty,
  weak,
  fair,
  good,
  strong,
}

class PasswordRequirement {
  const PasswordRequirement({
    required this.id,
    required this.label,
    required this.isMet,
  });

  final String id;
  final String label;
  final bool isMet;
}

abstract final class PasswordStrengthEvaluator {
  static List<PasswordRequirement> requirements(String password) {
    return [
      PasswordRequirement(
        id: 'length',
        label: '8+ characters',
        isMet: password.length >= 8,
      ),
      PasswordRequirement(
        id: 'upper',
        label: 'Uppercase letter',
        isMet: RegExp(r'[A-Z]').hasMatch(password),
      ),
      PasswordRequirement(
        id: 'lower',
        label: 'Lowercase letter',
        isMet: RegExp(r'[a-z]').hasMatch(password),
      ),
      PasswordRequirement(
        id: 'number',
        label: 'Number',
        isMet: RegExp(r'[0-9]').hasMatch(password),
      ),
      PasswordRequirement(
        id: 'special',
        label: 'Special character',
        isMet: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
      ),
    ];
  }

  static List<PasswordRequirement> missing(String password) {
    return requirements(password).where((item) => !item.isMet).toList();
  }

  static bool isStrong(String password) {
    return evaluate(password) == PasswordStrength.strong;
  }

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;

    final score = requirements(password).where((item) => item.isMet).length;

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

  static Color strengthColor(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => AppColors.textMuted,
        PasswordStrength.weak => AppColors.strengthWeak,
        PasswordStrength.fair => AppColors.strengthFair,
        PasswordStrength.good => AppColors.strengthGood,
        PasswordStrength.strong => AppColors.strengthStrong,
      };
}
