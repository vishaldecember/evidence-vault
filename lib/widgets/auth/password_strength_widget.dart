import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/password_strength.dart';

/// Progressive password coaching — reveal only what's missing.
class PasswordStrengthWidget extends StatefulWidget {
  const PasswordStrengthWidget({
    super.key,
    required this.password,
    this.confirmPassword = '',
  });

  final String password;
  final String confirmPassword;

  @override
  State<PasswordStrengthWidget> createState() => _PasswordStrengthWidgetState();
}

class _PasswordStrengthWidgetState extends State<PasswordStrengthWidget> {
  bool _showAllRequirements = false;

  @override
  Widget build(BuildContext context) {
    if (widget.password.isEmpty) {
      return const SizedBox.shrink();
    }

    final strong = PasswordStrengthEvaluator.isStrong(widget.password);
    final missing = PasswordStrengthEvaluator.missing(widget.password);
    final passwordsMatch = widget.confirmPassword.isNotEmpty &&
        widget.confirmPassword == widget.password;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (strong) ...[
            _StatusLine(
              icon: Icons.check_circle_rounded,
              label: 'Strong password',
              color: AppColors.success,
            ),
            if (!_showAllRequirements)
              GestureDetector(
                onTap: () => setState(() => _showAllRequirements = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    'View requirements',
                    style: AppTextStyles.link.copyWith(fontSize: 12),
                  ),
                ),
              ),
            if (_showAllRequirements) ...[
              const SizedBox(height: AppSpacing.xxs),
              ...PasswordStrengthEvaluator.requirements(widget.password).map(
                (item) => _RequirementLine(label: item.label, met: item.isMet),
              ),
              GestureDetector(
                onTap: () => setState(() => _showAllRequirements = false),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    'Hide requirements',
                    style: AppTextStyles.link.copyWith(fontSize: 12),
                  ),
                ),
              ),
            ],
          ] else ...[
            Text(
              'Missing:',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            ...missing.map(
              (item) => _RequirementLine(label: item.label, met: false),
            ),
          ],
          if (passwordsMatch) ...[
            const SizedBox(height: AppSpacing.xs),
            const _StatusLine(
              icon: Icons.check_circle_rounded,
              label: 'Passwords match',
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RequirementLine extends StatelessWidget {
  const _RequirementLine({
    required this.label,
    required this.met,
  });

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
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
