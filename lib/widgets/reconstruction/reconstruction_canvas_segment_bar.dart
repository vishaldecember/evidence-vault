import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/reconstruction_canvas_segment.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Top segmented navigation for the Reconstruction Canvas.
class ReconstructionCanvasSegmentBar extends StatelessWidget {
  const ReconstructionCanvasSegmentBar({
    super.key,
    required this.activeSegment,
    required this.onSegmentSelected,
  });

  final ReconstructionCanvasSegment activeSegment;
  final ValueChanged<ReconstructionCanvasSegment> onSegmentSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SegmentedButton<ReconstructionCanvasSegment>(
        segments: [
          for (final segment in ReconstructionCanvasSegment.values)
            ButtonSegment(
              value: segment,
              label: Text(
                segment.label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        selected: {activeSegment},
        onSelectionChanged: (selection) {
          onSegmentSelected(selection.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.onPrimary;
            }
            return AppColors.navy;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return AppColors.card;
          }),
        ),
      ),
    );
  }
}
