import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/storage/evidence_upload_coordinator.dart';
import '../../services/storage/evidence_upload_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../evidence/evidence_participant_chip.dart';
import 'living_evidence_preview.dart';

/// Connect-ready evidence thumbnail for the Incident Journey grid.
class JourneyEvidenceThumbnail extends StatefulWidget {
  const JourneyEvidenceThumbnail({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
    this.animateEntry = false,
    this.accentColor,
    this.showGroupBadge = false,
    this.participantDisplayName,
    this.frameBorderColor,
    this.paperSurfaceColor,
    this.identifyingTextColor,
  });

  static const Duration selectionDuration = Duration(milliseconds: 180);

  static const double size = LivingEvidencePreview.mediaSize;

  final WorkspaceEvidenceItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool animateEntry;

  /// Relationship group colour — pending or persisted.
  final Color? accentColor;

  /// Shows a small group colour badge when evidence belongs to a saved group.
  final bool showGroupBadge;
  final String? participantDisplayName;

  /// Unselected frame stroke. Null keeps the default faint accent border.
  final Color? frameBorderColor;

  /// Paper fill for note / attachment previews. Null keeps the default tint.
  final Color? paperSurfaceColor;

  /// Note / file identifying copy inside the thumbnail. Null keeps defaults.
  final Color? identifyingTextColor;

  @override
  State<JourneyEvidenceThumbnail> createState() =>
      _JourneyEvidenceThumbnailState();
}

class _JourneyEvidenceThumbnailState extends State<JourneyEvidenceThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryScale;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );
    _entryScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: AppMotion.enter),
    );

    if (widget.animateEntry) {
      _entryController.forward(from: 0);
    } else {
      _entryController.value = 1;
    }
  }

  @override
  void didUpdateWidget(JourneyEvidenceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateEntry && !oldWidget.animateEntry) {
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _ConnectReadyThumbnailFrame(
      isSelected: widget.isSelected,
      accentColor: widget.accentColor,
      showGroupBadge: widget.showGroupBadge,
      frameBorderColor: widget.frameBorderColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LivingEvidencePreview(
            item: widget.item,
            uniformThumbnailSize: true,
            suppressBorder: true,
            paperSurfaceColor: widget.paperSurfaceColor,
            identifyingTextColor: widget.identifyingTextColor,
            onTap: widget.onTap,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _UploadProgressBar(
                evidenceId: widget.item.id,
                domainStatus: widget.item.uploadStatus,
              ),
            ),
          ),
        ],
      ),
    );

    final Widget content;
    if (!widget.animateEntry && _entryController.value == 1) {
      content = frame;
    } else {
      content = ScaleTransition(scale: _entryScale, child: frame);
    }

    final participantName = widget.participantDisplayName;
    if (participantName == null) {
      return content;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(height: AppSpacing.xxs),
        EvidenceParticipantChip(displayName: participantName),
      ],
    );
  }
}

/// Compact calm sync status — tiny badge + thin bar, never a blocking percent UI.
class _UploadProgressBar extends StatelessWidget {
  const _UploadProgressBar({
    required this.evidenceId,
    required this.domainStatus,
  });

  final String evidenceId;
  final EvidenceUploadStatus domainStatus;

  @override
  Widget build(BuildContext context) {
    // Authoritative domain status wins — never leave Syncing after upload.
    if (domainStatus == EvidenceUploadStatus.uploaded) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: EvidenceUploadCoordinator.instance,
      builder: (context, _) {
        final progress = EvidenceUploadCoordinator.instance.progressFor(
          evidenceId,
        );
        if (progress == null) {
          return const SizedBox.shrink();
        }

        if (progress.status == EvidenceUploadStatus.uploaded) {
          return const SizedBox.shrink();
        }

        if (progress.status == EvidenceUploadStatus.failed) {
          return const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(3),
              child: _SyncBadge(label: 'Failed', color: AppColors.warning),
            ),
          );
        }

        if (!progress.status.showsProgressBadge) {
          return const SizedBox.shrink();
        }

        // Quiet sync — tiny cloud dot only. Never show upload percentages.
        return const Align(
          alignment: Alignment.topRight,
          child: Padding(padding: EdgeInsets.all(3), child: _QuietSyncDot()),
        );
      },
    );
  }
}

class _QuietSyncDot extends StatelessWidget {
  const _QuietSyncDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.onPrimary.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 8,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _ConnectReadyThumbnailFrame extends StatelessWidget {
  const _ConnectReadyThumbnailFrame({
    required this.isSelected,
    required this.child,
    this.accentColor,
    this.showGroupBadge = false,
    this.frameBorderColor,
  });

  final bool isSelected;
  final Widget child;
  final Color? accentColor;
  final bool showGroupBadge;
  final Color? frameBorderColor;

  static const double _radius = AppSpacing.sm;

  Color get _baseAccent => accentColor ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.04 : 1,
      duration: JourneyEvidenceThumbnail.selectionDuration,
      curve: AppMotion.enter,
      child: AnimatedContainer(
        duration: JourneyEvidenceThumbnail.selectionDuration,
        curve: AppMotion.enter,
        width: JourneyEvidenceThumbnail.size,
        height: JourneyEvidenceThumbnail.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: isSelected
                ? _baseAccent
                : frameBorderColor ??
                      _baseAccent.withValues(
                        alpha: accentColor == null ? 0.32 : 0.45,
                      ),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _baseAccent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_radius - 1),
              child: child,
            ),
            if (showGroupBadge && accentColor != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _baseAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _baseAccent.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
