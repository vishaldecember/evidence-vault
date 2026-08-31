import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/workspace_evidence_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Explains Evidence Map readiness from real incident state (Sprint 2.1).
class EvidenceMapReadiness {
  const EvidenceMapReadiness({
    required this.hasEvidence,
    required this.hasChronology,
    required this.hasSupportingContext,
    required this.hasConnections,
  });

  final bool hasEvidence;
  final bool hasChronology;
  final bool hasSupportingContext;
  final bool hasConnections;

  /// Map is useful once evidence exists and at least one enrichment signal.
  bool get isReady =>
      hasEvidence && (hasSupportingContext || hasConnections);

  factory EvidenceMapReadiness.fromController(
    WorkspaceEvidenceController controller,
  ) {
    final evidence = controller.currentIncident.evidence;
    final hasEvidence = evidence.isNotEmpty;
    final hasChronology = evidence.any((e) => e.isPrimaryChronologyEvidence);
    final hasSupporting = evidence.any((e) => e.isSupportingEvidence);
    final hasConnections = controller.state.relationships.isNotEmpty ||
        controller.state.relationshipGroups.isNotEmpty ||
        controller.currentIncident.relationshipGroups.isNotEmpty ||
        evidence.any((e) => e.relatedEvidenceIds.isNotEmpty) ||
        evidence.any((e) => e.parentEvidenceId != null);
    return EvidenceMapReadiness(
      hasEvidence: hasEvidence,
      hasChronology: hasChronology,
      hasSupportingContext: hasSupporting,
      hasConnections: hasConnections,
    );
  }
}

/// Premium sheet when Evidence Map is not ready — no fake map data.
Future<void> showEvidenceMapReadinessSheet({
  required BuildContext context,
  required EvidenceMapReadiness readiness,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Evidence Map isn’t ready yet.',
              style: AppTextStyles.heading.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add more connected evidence, context, or additional '
              'evidence types to build the map.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Evidence Map needs:',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _StatusLine(
              label: 'Evidence captured',
              present: readiness.hasEvidence,
            ),
            _StatusLine(
              label: 'Chronology',
              present: readiness.hasChronology,
            ),
            _StatusLine(
              label: 'Additional evidence',
              present: readiness.hasSupportingContext,
            ),
            _StatusLine(
              label: 'Connections',
              present: readiness.hasConnections,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.present,
  });

  final String label;
  final bool present;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            present ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: present ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: present ? AppColors.navy : AppColors.textSecondary,
              fontWeight: present ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
