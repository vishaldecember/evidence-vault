import 'package:flutter/material.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/investigation/reconstruction_canvas_layout.dart';
import 'reconstruction_story_canvas.dart';

/// Reconstruction perspective — space × time storytelling canvas.
class ReconstructionWorkspace extends StatelessWidget {
  const ReconstructionWorkspace({
    super.key,
    required this.incidentId,
    required this.evidence,
    required this.onEvidenceTap,
    this.collections = const [],
    this.organizeCreatedIds = const {},
    this.contextAnchors = const [],
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> evidence;
  final List<EvidenceCollection> collections;
  final Set<String> organizeCreatedIds;
  final List<OrganizeContextAnchor> contextAnchors;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;

  static const scrollStorageKey = PageStorageKey<String>(
    'investigation_reconstruction_workspace_scroll',
  );

  static Key nodeKey(String id) => ReconstructionStoryCanvas.nodeKey(id);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: ValueKey<String>('reconstruction_workspace_$incidentId'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : ReconstructionCanvasLayout.defaultViewport.width,
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : ReconstructionCanvasLayout.defaultViewport.height,
          );
          final plot = ReconstructionCanvasLayout.fromEvidence(
            evidence: evidence,
            collections: collections,
            organizeCreatedIds: organizeCreatedIds,
            contextAnchors: contextAnchors,
            viewport: viewport,
          );
          return ReconstructionStoryCanvas(
            key: ReconstructionWorkspace.scrollStorageKey,
            plot: plot,
            onEvidenceTap: onEvidenceTap,
          );
        },
      ),
    );
  }
}
