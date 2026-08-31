import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_artifact_model.dart';
import '../../models/linked_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_colors.dart';

/// Compact read-only thumbnail for one linked artifact on the Evidence Record.
class LinkedEvidenceThumbnail extends StatelessWidget {
  const LinkedEvidenceThumbnail({
    super.key,
    required this.item,
    this.onTap,
  });

  static const double size = 52;

  final LinkedEvidenceItem item;
  final VoidCallback? onTap;

  Color get _accentColor {
    final index = item.relationshipGroupColorIndex;
    if (index == null) {
      return AppColors.primary;
    }
    return RelationshipGroupColorService.colorForIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: item.artifactType.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              _iconFor(item.artifactType),
              color: _accentColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(EvidenceArtifactType type) => switch (type) {
        EvidenceArtifactType.photo => Icons.photo_outlined,
        EvidenceArtifactType.video => Icons.videocam_outlined,
        EvidenceArtifactType.voiceRecording => Icons.mic_outlined,
        EvidenceArtifactType.note => Icons.edit_note_outlined,
        EvidenceArtifactType.document => Icons.insert_drive_file_outlined,
      };
}
