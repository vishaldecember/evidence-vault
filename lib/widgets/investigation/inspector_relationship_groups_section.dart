import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';

/// Read-only relationship group membership for the investigation inspector.
class InspectorRelationshipGroupsSection extends StatelessWidget {
  const InspectorRelationshipGroupsSection({
    super.key,
    required this.evidence,
    required this.relationshipGroups,
  });

  final WorkspaceEvidenceItem evidence;
  final List<RelationshipGroup> relationshipGroups;

  @override
  Widget build(BuildContext context) {
    final groups = RelationshipGroupColorService.orderedGroups(
      relationshipGroups
          .where((group) => group.memberEvidenceIds.contains(evidence.id))
          .toList(),
    );

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(title: 'Relationship Groups'),
          const SizedBox(height: AppSpacing.md),
          if (groups.isEmpty)
            Text(
              'No relationship groups yet. Organize related artifacts in the '
              'Connections workspace.',
              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
            )
          else
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor:
                        RelationshipGroupColorService.colorForGroup(groups[i]),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      RelationshipGroupColorService.displayName(
                        groups[i],
                        relationshipGroups,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
