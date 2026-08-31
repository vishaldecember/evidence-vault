import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../navigation/incident_action_hierarchy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';
import '../common/premium_cta_button.dart';

/// Home card for an incident the user can keep preserving.
///
/// Does not expose CaptureSession lifecycle language — Continue preserving
/// continues documentation of the situation.
class SessionResumeCard extends StatelessWidget {
  const SessionResumeCard({
    super.key,
    required this.incidentTitle,
    required this.evidenceCount,
    required this.lastActivityLabel,
    required this.onContinueCapture,
    this.onContinueInvestigation,
  });

  final String incidentTitle;
  final int evidenceCount;
  final String lastActivityLabel;
  final VoidCallback onContinueCapture;
  final VoidCallback? onContinueInvestigation;

  String get _displayTitle {
    final trimmed = incidentTitle.trim();
    if (trimmed.isEmpty || trimmed == 'Untitled Incident') {
      return 'Open incident';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return LayeredCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayTitle,
            key: const Key('session_resume_title'),
            style: AppTextStyles.heading.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            softWrap: true,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _IncidentMetadataRow(
            lastActivityLabel: lastActivityLabel,
            evidenceCount: evidenceCount,
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCtaButton(
            key: const Key('session_resume_continue_capture'),
            label: IncidentActionHierarchy.preserveLabel,
            onPressed: onContinueCapture,
          ),
          if (onContinueInvestigation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _StageActionButton(
              key: const Key('session_resume_continue_investigation'),
              label: IncidentActionHierarchy.investigateLabel,
              onPressed: onContinueInvestigation!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Last activity and evidence count as incident metadata — not a primary action.
class _IncidentMetadataRow extends StatelessWidget {
  const _IncidentMetadataRow({
    required this.lastActivityLabel,
    required this.evidenceCount,
  });

  final String lastActivityLabel;
  final int evidenceCount;

  @override
  Widget build(BuildContext context) {
    final metaStyle = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      height: 1.3,
    );
    return Wrap(
      key: const Key('session_resume_metadata_row'),
      spacing: AppSpacing.sm,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Last activity  $lastActivityLabel',
          key: const Key('session_resume_last_activity'),
          style: metaStyle,
        ),
        Text('•', style: metaStyle),
        Text(
          '$evidenceCount evidence',
          key: const Key('session_resume_evidence_count'),
          style: metaStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Full-width secondary stage action with a comfortable thumb target.
class _StageActionButton extends StatelessWidget {
  const _StageActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppAccessibility.minTouchTarget,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
          minimumSize: const Size(
            double.infinity,
            AppAccessibility.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
