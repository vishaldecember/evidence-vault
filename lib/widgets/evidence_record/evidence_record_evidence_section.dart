import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_record_model.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../verification/verification_badge.dart';
import '../workspace/workspace_card.dart';
import 'evidence_record_info_row.dart';
import 'evidence_record_preview.dart';

/// Pillar 1 — Evidence
///
/// Answers: "What was preserved?"
/// Read-only preview and attribution. The artifact is never editable here.
class EvidenceRecordEvidenceSection extends StatelessWidget {
  const EvidenceRecordEvidenceSection({super.key, required this.record});

  final EvidenceRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvidenceRecordPreview(record: record),
        const SizedBox(height: AppSpacing.sm),
        WorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: WorkspaceSectionHeader(title: 'Evidence'),
                  ),
                  if (!record.verification.isNotVerified)
                    VerificationBadge(verification: record.verification),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              EvidenceRecordInfoRow(
                label: 'Evidence Type',
                value: record.type.label,
              ),
              for (final clock
                  in EvidenceInspectorSemantics.instants(record.evidence))
                EvidenceRecordInfoRow(
                  label: clock.label,
                  value: clock.formatted,
                ),
              EvidenceRecordInfoRow(
                label: 'Source',
                value: record.metadata.source,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
