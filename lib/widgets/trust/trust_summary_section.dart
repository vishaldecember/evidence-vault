import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_record_model.dart';
import '../../models/trust_summary_model.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../workspace/workspace_card.dart';
import 'trust_summary_card.dart';

/// Automatic trust reassurance for preserved evidence — read-only, no user input.
class TrustSummarySection extends StatelessWidget {
  const TrustSummarySection({
    super.key,
    required this.record,
    this.sectionTitle = EvidenceInspectorSemantics.completeRecordIntegrityTitle,
  });

  final EvidenceRecordModel record;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    final summary = TrustSummaryModel.fromRecord(record);

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionHeader(title: sectionTitle),
          const SizedBox(height: AppSpacing.md),
          TrustSummaryCard(summary: summary),
        ],
      ),
    );
  }
}
