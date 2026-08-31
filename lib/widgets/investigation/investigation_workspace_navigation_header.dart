import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/investigation_methodology_stage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_back_button.dart';
import 'investigation_journey_header.dart';

/// Fixed premium navigation chrome for the Investigation Workspace.
///
/// Combines back navigation, workspace title, methodology journey, and the
/// active-stage subtitle into one non-scrolling header region.
class InvestigationWorkspaceNavigationHeader extends StatelessWidget {
  const InvestigationWorkspaceNavigationHeader({
    super.key,
    required this.activeStage,
    required this.onStageSelected,
    this.trailing,
  });

  final InvestigationMethodologyStage activeStage;
  final ValueChanged<InvestigationMethodologyStage> onStageSelected;
  final Widget? trailing;

  static TextStyle get titleStyle => AppTextStyles.label.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: -0.2,
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxs,
          AppSpacing.xxs,
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AppBackButton(),
                Expanded(
                  child: Text(
                    'Investigation Workspace',
                    style: titleStyle,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            InvestigationJourneyHeader(
              activeStage: activeStage,
              onStageSelected: onStageSelected,
            ),
          ],
        ),
      ),
    );
  }
}
