import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/password_strength.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  Color _segmentColor(PasswordStrength strength, int index) {
    final activeColor = switch (strength) {
      PasswordStrength.empty => AppColors.strengthTrack,
      PasswordStrength.weak => AppColors.strengthWeak,
      PasswordStrength.fair => AppColors.strengthFair,
      PasswordStrength.good => AppColors.strengthGood,
      PasswordStrength.strong => AppColors.strengthStrong,
    };

    final activeSegments = switch (strength) {
      PasswordStrength.empty => 0,
      PasswordStrength.weak => 1,
      PasswordStrength.fair => 2,
      PasswordStrength.good => 3,
      PasswordStrength.strong => 4,
    };

    return index < activeSegments ? activeColor : AppColors.strengthTrack;
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEvaluator.evaluate(password);
    final label = PasswordStrengthEvaluator.label(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == 3 ? 0 : AppSpacing.xxs + 2,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: AppSpacing.xxs,
                  decoration: BoxDecoration(
                    color: _segmentColor(strength, index),
                    borderRadius: BorderRadius.circular(AppSpacing.xxs),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTextStyles.strengthLabel),
        if (password.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _CriteriaRow(
            label: '8+ characters',
            met: password.length >= 8,
          ),
          _CriteriaRow(
            label: 'Uppercase letter',
            met: RegExp(r'[A-Z]').hasMatch(password),
          ),
          _CriteriaRow(
            label: 'Lowercase letter',
            met: RegExp(r'[a-z]').hasMatch(password),
          ),
          _CriteriaRow(
            label: 'Number',
            met: RegExp(r'[0-9]').hasMatch(password),
          ),
          _CriteriaRow(
            label: 'Symbol',
            met: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
          ),
        ],
      ],
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  final String label;
  final bool met;

  const _CriteriaRow({
    required this.label,
    required this.met,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: met ? AppColors.success : AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
