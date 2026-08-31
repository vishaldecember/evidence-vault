import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/journey_stage.dart';
import '../../models/library_incident_summary.dart';
import '../../services/narrative_validation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/status_badge.dart';

/// Home resume card for an active investigation — hidden when no incident.
///
/// Entire surface is tappable; hierarchy leads with the incident name.
class ResumeIncidentCard extends StatelessWidget {
  const ResumeIncidentCard({
    super.key,
    required this.incident,
    required this.onContinue,
    this.journeyStage = JourneyStage.building,
    this.reconstructionHealth,
  });

  final LibraryIncidentSummary incident;
  final VoidCallback onContinue;
  final JourneyStage journeyStage;

  /// Optional live narrative health — presentation only, no persistence.
  final ReconstructionHealthStatus? reconstructionHealth;

  /// Home resume title — untitled in-progress work reads as pending.
  static String displayTitleFor(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == 'Untitled Incident') {
      return 'Pending Untitled Incident';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final status = IncidentStatus.resolve(
      journeyStage: journeyStage,
      health: reconstructionHealth,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitleFor(incident.title),
                style: AppTextStyles.heading.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Continue Investigation',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Last edited  ${incident.lastPreserved}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Evidence ${incident.evidenceCount}'
                '  ·  Narrative ${incident.narrativeCount}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
