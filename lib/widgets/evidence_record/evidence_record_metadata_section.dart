import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_record_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';
import 'evidence_record_info_row.dart';

/// Pillar 4 — Metadata
///
/// Answers: "Where did it come from?"
/// Displays available capture attribution only; unavailable fields are hidden.
class EvidenceRecordMetadataSection extends StatelessWidget {
  const EvidenceRecordMetadataSection({
    super.key,
    required this.record,
    this.compact = false,
  });

  final EvidenceRecordModel record;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = _availableRows(record);
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Metadata',
            style: AppTextStyles.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xxs),
            EvidenceRecordInfoRow(label: rows[i].$1, value: rows[i].$2),
          ],
        ],
      );
    }

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(title: 'Metadata'),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            EvidenceRecordInfoRow(label: rows[i].$1, value: rows[i].$2),
          ],
        ],
      ),
    );
  }

  List<(String, String)> _availableRows(EvidenceRecordModel record) {
    final meta = record.metadata;

    // Capture / record clocks live on the Evidence / Inspector fact rows.
    // This section is source metadata only — never a second "Capture date".
    return [
      if (meta.device != null) ('Device', meta.device!),
      if (meta.location != null) ('Location', meta.location!),
      if (meta.fileSize != null) ('File size', meta.fileSize!),
      if (meta.duration != null) ('Duration', meta.duration!),
      if (meta.resolution != null) ('Resolution', meta.resolution!),
    ];
  }
}
