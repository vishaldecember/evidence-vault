import 'package:flutter/material.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/investigation/reconstruction_canvas_layout.dart';
import '../../services/investigation/reconstruction_location_label_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'reconstruction_story_canvas.dart';

/// Reconstruction perspective — space × time storytelling canvas.
class ReconstructionWorkspace extends StatefulWidget {
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
  State<ReconstructionWorkspace> createState() =>
      _ReconstructionWorkspaceState();
}

class _ReconstructionWorkspaceState extends State<ReconstructionWorkspace> {
  final _store = ReconstructionLocationLabelStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onLabels);
    _store.hydrate(widget.incidentId);
  }

  @override
  void didUpdateWidget(ReconstructionWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentId != widget.incidentId) {
      _store.hydrate(widget.incidentId);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onLabels);
    super.dispose();
  }

  void _onLabels() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editLocation(ReconstructionLocationBand band) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return _LocationLabelDialog(
          initial: band.label == ReconstructionCanvasLayout.addLocationLabel
              ? ''
              : band.label,
        );
      },
    );
    if (result == null) {
      return;
    }
    await _store.save(
      incidentId: widget.incidentId,
      locationKey: band.key,
      label: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
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
            evidence: widget.evidence,
            collections: widget.collections,
            organizeCreatedIds: widget.organizeCreatedIds,
            contextAnchors: widget.contextAnchors,
            locationLabels: _store.labelsFor(widget.incidentId),
            viewport: viewport,
          );
          return ReconstructionStoryCanvas(
            key: ReconstructionWorkspace.scrollStorageKey,
            plot: plot,
            onEvidenceTap: widget.onEvidenceTap,
            onEditLocation: _editLocation,
          );
        },
      ),
    );
  }
}

class _LocationLabelDialog extends StatefulWidget {
  const _LocationLabelDialog({required this.initial});

  final String initial;

  @override
  State<_LocationLabelDialog> createState() => _LocationLabelDialogState();
}

class _LocationLabelDialogState extends State<_LocationLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.inspectorSurface,
      title: Text(
        'Where did this happen?',
        style: AppTextStyles.emphasisLabel.copyWith(color: AppColors.onCanvas),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppTextStyles.body.copyWith(color: AppColors.onCanvas),
        decoration: InputDecoration(
          hintText: 'Place, street, or building',
          hintStyle: AppTextStyles.caption.copyWith(
            color: AppColors.onCanvasSecondary,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
