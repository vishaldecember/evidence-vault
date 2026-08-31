import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/organize_visuals.dart';
import '../common/thumbnail_atmosphere_surface.dart';
import 'journey_evidence_thumbnail.dart';
import 'organize_chronology_canvas.dart';
import 'organize_context_anchor_arrow.dart';

/// Visual overview of chronology evidence and linked context.
///
/// Derives order and relationships from existing Organize state. Does not
/// write chronology, invent snaps, or treat context as evidence.
class OrganizeCompositionMatrix extends StatelessWidget {
  const OrganizeCompositionMatrix({
    super.key,
    required this.evidence,
    this.anchors = const [],
    this.organizeCreatedIds = const {},
    this.orderedCapturedEvidenceIds = const [],
  });

  final List<WorkspaceEvidenceItem> evidence;
  final List<OrganizeContextAnchor> anchors;
  final Set<String> organizeCreatedIds;
  final List<String> orderedCapturedEvidenceIds;

  static const Key matrixKey = Key('organize_composition_matrix');
  static const Key unsnappedBandKey = Key(
    'organize_composition_unsnapped_band',
  );

  static Key chronologyCellKey(String evidenceId) =>
      Key('organize_composition_chronology_$evidenceId');

  static Key contextCellKey(String evidenceId) =>
      Key('organize_composition_context_$evidenceId');

  static const double _cell = 40;

  @override
  Widget build(BuildContext context) {
    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: evidence,
      orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
      organizeCreatedIds: organizeCreatedIds,
    );
    final chronology = [
      for (final item in ordered)
        if (OrganizeChronologyCanvas.isFixedSpineItem(
          item,
          organizeCreatedIds: organizeCreatedIds,
        ))
          item,
    ];
    final snappedIds = {
      for (final anchor in anchors) anchor.contextEvidenceId,
    };
    final unsnapped = [
      for (final item in ordered)
        if (OrganizeChronologyCanvas.isContextSpineItem(
              item,
              organizeCreatedIds: organizeCreatedIds,
            ) &&
            !snappedIds.contains(item.id))
          item,
    ];

    if (chronology.isEmpty && unsnapped.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      key: matrixKey,
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      children: [
        for (final item in chronology)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CompositionRow(
              captured: item,
              linked: _linkedTo(item.id, ordered),
            ),
          ),
        if (unsnapped.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              key: unsnappedBandKey,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < unsnapped.length; i++)
                  Transform.translate(
                    offset: Offset(i.isOdd ? 6 : 0, i.isOdd ? 4 : 0),
                    child: _MiniContext(item: unsnapped[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<WorkspaceEvidenceItem> _linkedTo(
    String capturedId,
    List<WorkspaceEvidenceItem> ordered,
  ) {
    final ids = {
      for (final anchor in anchors)
        if (anchor.capturedEvidenceId == capturedId) anchor.contextEvidenceId,
    };
    return [for (final item in ordered) if (ids.contains(item.id)) item];
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    required this.captured,
    required this.linked,
  });

  final WorkspaceEvidenceItem captured;
  final List<WorkspaceEvidenceItem> linked;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _MiniCaptured(item: captured),
        if (linked.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Transform.scale(
              scale: 0.72,
              child: OrganizeContextAnchorArrow(
                contextEvidenceId: linked.length == 1
                    ? linked.first.id
                    : 'cluster:${captured.id}',
                capturedEvidenceId: captured.id,
              ),
            ),
          ),
          if (linked.length == 1)
            _MiniContext(item: linked.single)
          else
            _MiniCluster(items: linked),
        ],
      ],
    );
  }
}

class _MiniCaptured extends StatelessWidget {
  const _MiniCaptured({required this.item});

  final WorkspaceEvidenceItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: OrganizeCompositionMatrix.chronologyCellKey(item.id),
      width: OrganizeCompositionMatrix._cell,
      height: OrganizeCompositionMatrix._cell,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ThumbnailAtmosphereSurface(),
            FittedBox(child: JourneyEvidenceThumbnail(item: item)),
          ],
        ),
      ),
    );
  }
}

class _MiniContext extends StatelessWidget {
  const _MiniContext({required this.item});

  final WorkspaceEvidenceItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: OrganizeCompositionMatrix.contextCellKey(item.id),
      width: OrganizeCompositionMatrix._cell,
      height: OrganizeCompositionMatrix._cell,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ThumbnailAtmosphereSurface(),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: OrganizeVisuals.contextBorder),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FittedBox(child: JourneyEvidenceThumbnail(item: item)),
          ],
        ),
      ),
    );
  }
}

class _MiniCluster extends StatelessWidget {
  const _MiniCluster({required this.items});

  final List<WorkspaceEvidenceItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: OrganizeCompositionMatrix._cell,
      height: OrganizeCompositionMatrix._cell,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ThumbnailAtmosphereSurface(),
            Padding(
              padding: const EdgeInsets.all(3),
              child: GridView.builder(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: items.length.clamp(0, 4),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: FittedBox(
                      child: JourneyEvidenceThumbnail(item: items[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
