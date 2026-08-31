import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../services/relationship_group_color_service.dart';
import 'capture_section_header.dart';

/// Compact Connect Mode entry — pill styling with Capture-matched typography.
class ConnectEvidencesPill extends StatelessWidget {
  const ConnectEvidencesPill({
    super.key,
    required this.onPressed,
    this.isActive = false,
    this.accentColorIndex = 0,
  });

  static const String connectLabel = 'Connect';
  static const String doneLabel = 'Done';

  final VoidCallback onPressed;
  final bool isActive;
  final int accentColorIndex;

  static const Duration _transitionDuration = Duration(milliseconds: 180);

  String get _label => isActive ? doneLabel : connectLabel;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        RelationshipGroupColorService.colorForIndex(accentColorIndex);

    return Semantics(
      button: true,
      label: _label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: _transitionDuration,
            curve: AppMotion.enter,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 1,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive
                    ? accentColor
                    : accentColor.withValues(alpha: 0.28),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              _label,
              textAlign: TextAlign.center,
              style: CaptureSectionHeader.titleStyle.copyWith(
                color: accentColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
