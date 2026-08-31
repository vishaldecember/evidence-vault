import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';
import 'connections_empty.dart';
import 'relationship_group_card.dart';

/// Connections — visual clusters of committed relationship groups.
class ConnectionsSection extends StatelessWidget {
  const ConnectionsSection({
    super.key,
    required this.relationshipGroups,
    required this.evidence,
    required this.onEvidenceSelected,
  });

  final List<RelationshipGroup> relationshipGroups;
  final List<WorkspaceEvidenceItem> evidence;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    final evidenceById = {for (final item in evidence) item.id: item};
    final orderedGroups =
        RelationshipGroupColorService.orderedGroups(relationshipGroups);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceSectionHeader(
          title: 'Connections',
          caption: 'Which evidence belongs together.',
          titleStyle: AppTextStyles.screenTitle.copyWith(fontSize: 22),
        ),
        const SizedBox(height: AppSpacing.md),
        if (orderedGroups.isEmpty)
          const ConnectionsEmpty()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orderedGroups.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final group = orderedGroups[index];
              return RepaintBoundary(
                child: RelationshipGroupCard(
                  group: group,
                  allGroups: orderedGroups,
                  evidenceById: evidenceById,
                  onEvidenceSelected: onEvidenceSelected,
                ),
              );
            },
          ),
      ],
    );
  }
}
