import 'package:flutter/material.dart';



import '../../../constants/app_spacing.dart';

import '../../../services/narrative_validation_service.dart';

import '../../../theme/app_colors.dart';

import '../../../theme/app_decorations.dart';

import '../../../theme/app_text_styles.dart';

import '../../common/status_badge.dart';



/// Header for the Structured Narrative Builder segment.

class NarrativeBuilderHeader extends StatelessWidget {

  const NarrativeBuilderHeader({

    super.key,

    required this.incidentName,

    required this.narrativeEventCount,

    required this.timelineAnchorCount,

    required this.relationshipGroupCount,

    required this.reconstructionHealth,

  });



  final String incidentName;

  final int narrativeEventCount;

  final int timelineAnchorCount;

  final int relationshipGroupCount;

  final NarrativeReconstructionHealth reconstructionHealth;



  @override

  Widget build(BuildContext context) {

    final resolvedName = incidentName.trim().isEmpty

        ? 'Untitled Incident'

        : incidentName.trim();

    final progressLabel = timelineAnchorCount == 0
        ? '0 Events Created'
        : '$narrativeEventCount of $timelineAnchorCount Events Created';
    final healthStatus = IncidentStatus.fromReconstructionHealth(
      reconstructionHealth.status,
    );

    return Container(

      margin: const EdgeInsets.only(bottom: AppSpacing.sm),

      padding: const EdgeInsets.all(AppSpacing.sm),

      decoration: AppDecorations.card(

        backgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.55),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Text(

            resolvedName,

            style: AppTextStyles.label.copyWith(

              fontWeight: FontWeight.w700,

              fontSize: 16,

              color: AppColors.navy,

            ),

          ),

          const SizedBox(height: AppSpacing.sm),

          Text(

            'Reconstruction Health',

            style: AppTextStyles.caption.copyWith(

              color: AppColors.textSecondary,

              fontWeight: FontWeight.w700,

            ),

          ),

          const SizedBox(height: AppSpacing.xxs),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(status: healthStatus),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Narrative Coverage',

            style: AppTextStyles.caption.copyWith(

              color: AppColors.textSecondary,

              fontWeight: FontWeight.w700,

            ),

          ),

          const SizedBox(height: AppSpacing.xxs),

          Text(

            reconstructionHealth.coverageLabel,

            style: AppTextStyles.caption.copyWith(

              color: AppColors.textSecondary,

              fontWeight: FontWeight.w600,

            ),

          ),

          const SizedBox(height: AppSpacing.sm),

          Wrap(

            spacing: AppSpacing.sm,

            runSpacing: AppSpacing.xxs,

            children: [

              _StatChip(label: 'Narrative Events', value: '$narrativeEventCount'),

              _StatChip(label: 'Primary Evidence', value: '$timelineAnchorCount'),

              _StatChip(

                label: 'Relationship Groups',

                value: '$relationshipGroupCount',

              ),

              _StatChip(label: 'Narrative Progress', value: progressLabel),

            ],

          ),

        ],

      ),

    );

  }

}



class _StatChip extends StatelessWidget {

  const _StatChip({required this.label, required this.value});



  final String label;

  final String value;



  @override

  Widget build(BuildContext context) {

    return Text(

      '$label: $value',

      style: AppTextStyles.caption.copyWith(

        color: AppColors.textSecondary,

        fontWeight: FontWeight.w600,

      ),

    );

  }

}

