import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_maturity.dart';
import '../../models/journey_stage.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../presentation/capture_maturity_progress.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/thumbnail_atmosphere_surface.dart';
import 'journey_evidence_thumbnail.dart';

/// Local Evidence Maturity chrome — does not change shared [AppColors].
abstract final class _EvidenceMaturitySurfaces {
  /// Nested Capture / Strengthening fill against [AppColors.surfaceMuted].
  static const nestedLane = Color(0xFFD6DCE6);

  /// Unselected capture thumbnail frame — thin, clearly visible, unsaturated.
  static const thumbnailBorder = Color(0xFF6B7588);

  /// Text Note / Attachment thumbnail paper.
  static const thumbnailPaper = Color(0xFFFFFFFF);
}

/// Premium Evidence Maturity Engine — three fixed lanes driven by
/// [EvidenceMaturity]. Stabilized Sprint 4G.1 foundation.
class EvidenceMaturityEngine extends StatefulWidget {
  const EvidenceMaturityEngine({
    super.key,
    required this.journeyEvidence,
    this.currentStage = JourneyStage.empty,
    this.onEvidenceSelected,
    this.animateEvidenceId,
    this.relationshipGroups = const [],
    this.connectModeActive = false,
    this.selectedEvidenceIds = const {},
    this.connectPendingColorIndex = 0,
    this.resolveParticipantName,
  });

  final List<WorkspaceEvidenceItem> journeyEvidence;
  final JourneyStage currentStage;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceSelected;
  final String? animateEvidenceId;
  final List<RelationshipGroup> relationshipGroups;
  final bool connectModeActive;
  final Set<String> selectedEvidenceIds;
  final int connectPendingColorIndex;
  final String? Function(String participantId)? resolveParticipantName;

  /// O-18: Strengthening duplicates Organize. Engine APIs remain.
  static const bool showStrengtheningLane = false;

  /// Motorola G35-class phones: at most five evidence cards per row.
  static const int maxCardsPerRowCompact = 5;
  static const int maxCardsPerRow = maxCardsPerRowCompact;

  @override
  State<EvidenceMaturityEngine> createState() => _EvidenceMaturityEngineState();
}

class _EvidenceMaturityEngineState extends State<EvidenceMaturityEngine> {
  String? _highlightedEvidenceId;
  _StrengtheningKind? _highlightedKind;

  List<WorkspaceEvidenceItem> _laneItems(EvidenceMaturity maturity) {
    return [
      for (final item in widget.journeyEvidence)
        if (item.maturity == maturity) item,
    ];
  }

  WorkspaceEvidenceItem? _matchForKind(_StrengtheningKind kind) {
    final supporting = _laneItems(EvidenceMaturity.building);
    for (final item in supporting) {
      if (kind.matches(item)) {
        return item;
      }
    }
    // Also allow matching primary-linked notes still in journey as building.
    for (final item in widget.journeyEvidence) {
      if (kind.matches(item)) {
        return item;
      }
    }
    return null;
  }

  void _onStrengtheningTap(_StrengtheningKind kind) {
    final match = _matchForKind(kind);
    final highlightId = match?.parentEvidenceId ?? match?.id;
    setState(() {
      _highlightedKind = kind;
      _highlightedEvidenceId = highlightId;
    });
  }

  void _onStrengtheningDoubleTap(_StrengtheningKind kind) {
    final match = _matchForKind(kind);
    _showStrengtheningFlyout(kind, match);
  }

  void _showStrengtheningFlyout(
    _StrengtheningKind kind,
    WorkspaceEvidenceItem? match,
  ) {
    final timestamp = match == null
        ? 'Not captured yet'
        : DateFormat('d MMM yyyy · HH:mm').format(match.lastPreservedAt);
    final description = match?.notePreview?.trim().isNotEmpty == true
        ? match!.notePreview!.trim()
        : match?.title ?? kind.emptyDescription;

    showDialog<void>(
      context: context,
      barrierColor: AppColors.navy.withValues(alpha: 0.28),
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.label,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  timestamp,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final captured = _laneItems(EvidenceMaturity.capture);
    final progress = CaptureMaturityProgress.evaluate(
      evidence: widget.journeyEvidence,
      journeyStage: widget.currentStage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MaturityLane(
          maturity: EvidenceMaturity.capture,
          surfaceColor: const Color(0xFFF4F8FB),
          atmosphere: true,
          child: captured.isEmpty
              ? const _LaneEmptyHint(message: 'Captured evidence appears here.')
              : _ResponsiveEvidenceGrid(
                  evidence: captured,
                  highlightedEvidenceId: _highlightedEvidenceId,
                  onEvidenceSelected: widget.onEvidenceSelected,
                  animateEvidenceId: widget.animateEvidenceId,
                  relationshipGroups: widget.relationshipGroups,
                  connectModeActive: widget.connectModeActive,
                  selectedEvidenceIds: widget.selectedEvidenceIds,
                  connectPendingColorIndex: widget.connectPendingColorIndex,
                  resolveParticipantName: widget.resolveParticipantName,
                ),
        ),
        if (EvidenceMaturityEngine.showStrengtheningLane) ...[
          const SizedBox(height: AppSpacing.md),
          _MaturityLane(
            maturity: EvidenceMaturity.building,
            surfaceColor: _EvidenceMaturitySurfaces.nestedLane,
            child: _StrengtheningPlaceholders(
              highlightedKind: _highlightedKind,
              onTap: _onStrengtheningTap,
              onDoubleTap: _onStrengtheningDoubleTap,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _MaturityLane(
          maturity: EvidenceMaturity.rich,
          surfaceColor: progress.isReached(
                CaptureMaturityStep.investigationReady,
              )
              ? const Color(0xFFDCE6F2)
              : AppColors.surfaceMuted.withValues(alpha: 0.45),
          child: _InvestigationReadyProgress(progress: progress),
        ),
      ],
    );
  }
}

class _MaturityLane extends StatelessWidget {
  const _MaturityLane({
    required this.maturity,
    required this.child,
    this.surfaceColor,
    this.atmosphere = false,
  });

  final EvidenceMaturity maturity;
  final Widget child;
  final Color? surfaceColor;
  final bool atmosphere;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.fieldRadius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          maturity.laneLabel,
          style: AppTextStyles.label.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor ??
                AppColors.surfaceMuted.withValues(alpha: 0.45),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.7),
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                if (atmosphere)
                  const Positioned.fill(
                    child: ThumbnailAtmosphereSurface(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LaneEmptyHint extends StatelessWidget {
  const _LaneEmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

enum _StrengtheningKind {
  textNote,
  attachment,
  anchor,
  relationshipLink;

  String get label => switch (this) {
        _StrengtheningKind.textNote => 'Text Note',
        _StrengtheningKind.attachment => 'Attachment',
        _StrengtheningKind.anchor => 'Primary Evidence',
        _StrengtheningKind.relationshipLink => 'Relationship',
      };

  IconData get icon => switch (this) {
        _StrengtheningKind.textNote => Icons.edit_note_rounded,
        _StrengtheningKind.attachment => Icons.attach_file_rounded,
        _StrengtheningKind.anchor => Icons.star_rounded,
        _StrengtheningKind.relationshipLink => Icons.link_rounded,
      };

  String get emptyDescription => switch (this) {
        _StrengtheningKind.textNote =>
          'Written notes that strengthen primary evidence.',
        _StrengtheningKind.attachment =>
          'Supporting files linked to this investigation.',
        _StrengtheningKind.anchor =>
          'Primary evidence that anchors the investigation chronology.',
        _StrengtheningKind.relationshipLink =>
          'Connections between related pieces of evidence.',
      };

  bool matches(WorkspaceEvidenceItem item) => switch (this) {
        _StrengtheningKind.textNote => item.kind == WorkspaceEvidenceKind.note,
        _StrengtheningKind.attachment =>
          item.kind == WorkspaceEvidenceKind.attachment,
        _StrengtheningKind.anchor => false,
        _StrengtheningKind.relationshipLink =>
          item.relatedEvidenceIds.isNotEmpty || item.parentEvidenceId != null,
      };
}

/// Strengthening lane — temporary interaction until Sprint 4G.2.
class _StrengtheningPlaceholders extends StatelessWidget {
  const _StrengtheningPlaceholders({
    required this.onTap,
    required this.onDoubleTap,
    this.highlightedKind,
  });

  final _StrengtheningKind? highlightedKind;
  final ValueChanged<_StrengtheningKind> onTap;
  final ValueChanged<_StrengtheningKind> onDoubleTap;

  static const _kinds = _StrengtheningKind.values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _ResponsiveWrap(
          maxPerRow: EvidenceMaturityEngine.maxCardsPerRow,
          availableWidth: constraints.maxWidth,
          itemCount: _kinds.length,
          itemBuilder: (index) {
            final kind = _kinds[index];
            return _PlaceholderChip(
              icon: kind.icon,
              label: kind.label,
              accent: const Color(0xFFB45309),
              paperColor: kind == _StrengtheningKind.textNote ||
                      kind == _StrengtheningKind.attachment
                  ? _EvidenceMaturitySurfaces.thumbnailPaper
                  : null,
              highlighted: highlightedKind == kind,
              onTap: () => onTap(kind),
              onDoubleTap: () => onDoubleTap(kind),
            );
          },
        );
      },
    );
  }
}

class _PlaceholderChip extends StatelessWidget {
  const _PlaceholderChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.highlighted,
    required this.onTap,
    required this.onDoubleTap,
    this.paperColor,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color? paperColor;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: paperColor,
                gradient: paperColor != null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFFBF5),
                          accent.withValues(alpha: highlighted ? 0.28 : 0.12),
                        ],
                      ),
                border: Border.all(
                  color: accent.withValues(alpha: highlighted ? 0.85 : 0.35),
                  width: highlighted ? 1.5 : 1,
                ),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, size: 26, color: accent),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live Investigation Ready steps — derived from existing maturity engines.
class _InvestigationReadyProgress extends StatelessWidget {
  const _InvestigationReadyProgress({required this.progress});

  final CaptureMaturityProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in CaptureMaturityStep.values) ...[
          if (step != CaptureMaturityStep.values.first)
            const SizedBox(height: AppSpacing.xs),
          _MaturityStepRow(
            step: step,
            reached: progress.isReached(step),
          ),
        ],
      ],
    );
  }
}

class _MaturityStepRow extends StatelessWidget {
  const _MaturityStepRow({
    required this.step,
    required this.reached,
  });

  final CaptureMaturityStep step;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppColors.navy : AppColors.textMuted;
    return Semantics(
      key: CaptureMaturityProgress.keyFor(step),
      label: step.label,
      selected: reached,
      child: Row(
        children: [
          Icon(
            reached ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: reached ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              step.label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Captured lane — chronological primary evidence, max 5 cards/row, no h-scroll.
class _ResponsiveEvidenceGrid extends StatelessWidget {
  const _ResponsiveEvidenceGrid({
    required this.evidence,
    this.highlightedEvidenceId,
    this.onEvidenceSelected,
    this.animateEvidenceId,
    this.relationshipGroups = const [],
    this.connectModeActive = false,
    this.selectedEvidenceIds = const {},
    this.connectPendingColorIndex = 0,
    this.resolveParticipantName,
  });

  final List<WorkspaceEvidenceItem> evidence;
  final String? highlightedEvidenceId;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceSelected;
  final String? animateEvidenceId;
  final List<RelationshipGroup> relationshipGroups;
  final bool connectModeActive;
  final Set<String> selectedEvidenceIds;
  final int connectPendingColorIndex;
  final String? Function(String participantId)? resolveParticipantName;

  Color? _accentFor(WorkspaceEvidenceItem item) {
    if (highlightedEvidenceId == item.id) {
      return const Color(0xFFB45309);
    }
    if (connectModeActive && selectedEvidenceIds.contains(item.id)) {
      return RelationshipGroupColorService.colorForIndex(
        connectPendingColorIndex,
      );
    }

    final savedGroup = RelationshipGroupColorService.groupForEvidence(
      item.id,
      relationshipGroups,
    );
    if (savedGroup != null) {
      return RelationshipGroupColorService.colorForGroup(savedGroup);
    }
    return null;
  }

  bool _showBadgeFor(WorkspaceEvidenceItem item) {
    if (highlightedEvidenceId == item.id) {
      return true;
    }
    if (connectModeActive && selectedEvidenceIds.contains(item.id)) {
      return true;
    }
    return RelationshipGroupColorService.groupForEvidence(
          item.id,
          relationshipGroups,
        ) !=
        null;
  }

  String? _participantNameFor(WorkspaceEvidenceItem item) {
    final participantId = item.participantId;
    if (participantId == null || resolveParticipantName == null) {
      return null;
    }
    return resolveParticipantName!(participantId);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumb = JourneyEvidenceThumbnail.size;
        const connector = 30.0;
        const spacing = AppSpacing.xxs;
        final slot = thumb + connector + spacing;
        final fitted =
            ((constraints.maxWidth + spacing) / slot).floor().clamp(1, 100);
        final perRow = fitted > EvidenceMaturityEngine.maxCardsPerRow
            ? EvidenceMaturityEngine.maxCardsPerRow
            : fitted;

        final rows = <Widget>[];
        for (var start = 0; start < evidence.length; start += perRow) {
          final end = (start + perRow).clamp(0, evidence.length);
          final rowItems = evidence.sublist(start, end);
          rows.add(
            Wrap(
              spacing: spacing,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < rowItems.length; i++) ...[
                  JourneyEvidenceThumbnail(
                    key: ValueKey(rowItems[i].id),
                    item: rowItems[i],
                    frameBorderColor:
                        _EvidenceMaturitySurfaces.thumbnailBorder,
                    paperSurfaceColor:
                        _EvidenceMaturitySurfaces.thumbnailPaper,
                    animateEntry: rowItems[i].id == animateEvidenceId,
                    isSelected: (connectModeActive &&
                            selectedEvidenceIds.contains(rowItems[i].id)) ||
                        highlightedEvidenceId == rowItems[i].id,
                    accentColor: _accentFor(rowItems[i]),
                    showGroupBadge: _showBadgeFor(rowItems[i]),
                    participantDisplayName: _participantNameFor(rowItems[i]),
                    onTap: onEvidenceSelected == null
                        ? null
                        : () => onEvidenceSelected!(rowItems[i]),
                  ),
                  if (i < rowItems.length - 1)
                    _SemanticEvidenceConnector(leadingTo: rowItems[i + 1]),
                ],
              ],
            ),
          );
          if (end < evidence.length) {
            rows.add(const SizedBox(height: AppSpacing.sm));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

/// Generic wrap helper capped at [maxPerRow] — no horizontal scrolling.
class _ResponsiveWrap extends StatelessWidget {
  const _ResponsiveWrap({
    required this.maxPerRow,
    required this.availableWidth,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int maxPerRow;
  final double availableWidth;
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    // Natural Wrap already wraps; maxPerRow is enforced via soft width budget.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < itemCount; i++) itemBuilder(i),
      ],
    );
  }
}

/// Orange when leading to primary chronology; blue for supporting.
class _SemanticEvidenceConnector extends StatelessWidget {
  const _SemanticEvidenceConnector({required this.leadingTo});

  final WorkspaceEvidenceItem leadingTo;

  @override
  Widget build(BuildContext context) {
    final color = leadingTo.isPrimaryChronologyEvidence
        ? AppColors.timelineChronology
        : AppColors.timelineSupporting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 22,
        color: color.withValues(alpha: 0.9),
      ),
    );
  }
}
