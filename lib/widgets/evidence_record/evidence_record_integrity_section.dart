import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_record_model.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';

/// Pillar 2 — Integrity
///
/// Answers: "Can I trust it?"
/// Extension points reserved for hash, verification history, and chain of custody.
class EvidenceRecordIntegritySection extends StatelessWidget {
  const EvidenceRecordIntegritySection({super.key, required this.record});

  final EvidenceRecordModel record;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(title: 'Integrity'),
          const SizedBox(height: AppSpacing.md),
          Text(
            EvidenceInspectorSemantics.integrityStatus(record.evidence),
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (EvidenceInspectorSemantics.contentHash(record.evidence) !=
              null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              EvidenceInspectorSemantics.hashLabel,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SelectableText(
              EvidenceInspectorSemantics.contentHash(record.evidence)!,
              style: AppTextStyles.bodySmall.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Digital integrity is not a claim about what happened '
            'in the real world. A hash, when present, can only show '
            'that a preserved file matches its recorded representation.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
