import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/risk_coach_controller.dart';
import '../../domain/risk/incident_risk_assessment.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';

/// Calm Risk Coach surface for Investigation Workspace (Sprint 5E).
///
/// Not a checklist, chatbot, or legal advisor.
class RiskCoachPanel extends StatelessWidget {
  const RiskCoachPanel({
    super.key,
    required this.controller,
    required this.onAction,
  });

  final RiskCoachController controller;
  final void Function(IncidentRiskAssessment assessment) onAction;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isReady) {
          return const SizedBox.shrink();
        }

        final items = controller.assessments;
        final wellSupported = controller.wellSupported && items.isEmpty;

        return Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: LayeredCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Risk Coach',
                style: AppTextStyles.label.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (items.isEmpty)
                _EmptyOrSupported(wellSupported: wellSupported)
              else ...[
                Text(
                  items.length == 1
                      ? '1 thing may need attention'
                      : '${items.length} things may need attention',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _RiskCard(
                    assessment: items[i],
                    onAction: () => onAction(items[i]),
                    onDismiss: () => controller.dismiss(items[i].id),
                  ),
                ],
              ],
            ],
          ),
          ),
        );
      },
    );
  }
}

class _EmptyOrSupported extends StatelessWidget {
  const _EmptyOrSupported({required this.wellSupported});

  final bool wellSupported;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.elevatedSection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            wellSupported
                ? 'Investigation looks well supported.'
                : 'Nothing needs your attention yet.',
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            wellSupported
                ? 'Primary evidence, supporting context, and collections are '
                    'in place. Capture more only if something new emerges.'
                : 'Capture more information and we’ll surface potential gaps '
                    'as your investigation develops.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (wellSupported) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '✓ Primary evidence identified\n'
              '✓ Supporting evidence connected\n'
              '✓ Evidence collections organized',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.assessment,
    required this.onAction,
    required this.onDismiss,
  });

  final IncidentRiskAssessment assessment;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            assessment.riskType.displayLabel,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            assessment.reason,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.navy,
              height: 1.4,
            ),
          ),
          if (assessment.sourceLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Source',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              assessment.sourceLabel!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    assessment.recommendedAction.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Dismiss',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
