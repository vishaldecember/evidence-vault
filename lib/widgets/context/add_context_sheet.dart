import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/context_type.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_bottom_sheet.dart';

/// Opens the Add Context bottom sheet — context is additive, evidence is immutable.
Future<void> showAddContextSheet({
  required BuildContext context,
  required ValueChanged<WorkspaceCaptureMode> onOptionSelected,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (context) {
      return AddContextSheet(
        onOptionSelected: (type) {
          Navigator.pop(context);
          onOptionSelected(ContextType.toCaptureMode(type));
        },
      );
    },
  );
}

class AddContextSheet extends StatelessWidget {
  const AddContextSheet({
    super.key,
    required this.onOptionSelected,
  });

  final ValueChanged<ContextType> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return BottomSheetInsets(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHeader(
            title: 'Add Context',
            caption: 'Context enriches this evidence without changing the original.',
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < ContextType.phase1.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            _ContextOptionTile(
              type: ContextType.phase1[i],
              onTap: () => onOptionSelected(ContextType.phase1[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextOptionTile extends StatelessWidget {
  const _ContextOptionTile({
    required this.type,
    required this.onTap,
  });

  final ContextType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(type.icon, color: AppColors.primary, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  type.addActionLabel,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
