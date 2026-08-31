import 'package:flutter/material.dart';



import '../../constants/app_spacing.dart';

import '../../models/evidence_artifact_model.dart';

import '../../models/workspace_evidence_item.dart';

import '../../theme/app_text_styles.dart';

import '../evidence/evidence_artifact_card.dart';

import 'evidence_map_empty.dart';

import 'workspace_card.dart';



/// Evidence Map — a curated collection of preserved evidence artifacts.

class EvidenceMapSection extends StatelessWidget {

  const EvidenceMapSection({

    super.key,

    required this.evidence,

    required this.onEvidenceSelected,

  });



  final List<WorkspaceEvidenceItem> evidence;

  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;



  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        WorkspaceSectionHeader(

          title: 'Evidence Map',

          caption: 'Review what you have preserved.',

          titleStyle: AppTextStyles.screenTitle.copyWith(fontSize: 22),

        ),

        const SizedBox(height: AppSpacing.md),

        if (evidence.isEmpty)

          const EvidenceMapEmpty()

        else

          ListView.separated(

            shrinkWrap: true,

            physics: const NeverScrollableScrollPhysics(),

            itemCount: evidence.length,

            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),

            itemBuilder: (context, index) {

              final item = evidence[index];

              return RepaintBoundary(

                child: EvidenceArtifactCard(

                  artifact: EvidenceArtifactModel.fromWorkspaceItem(item),

                  onTap: () => onEvidenceSelected(item),

                ),

              );

            },

          ),

      ],

    );

  }

}

