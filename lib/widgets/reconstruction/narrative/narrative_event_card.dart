import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../domain/reconstruction/narrative_event.dart';
import '../../../engines/narrative_builder.dart';
import '../../../models/workspace_evidence_item.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/investigation_selection_visuals.dart';
import '../../common/silver_lustre_text.dart';
import 'narrative_validation_summary.dart';
import '../../timeline/timeline_evidence_labels.dart';
import '../../workspace/living_evidence_preview.dart';
import '../../investigation/evidence_review_halo.dart';

/// One editable, evidence-backed narrative event card.
class NarrativeEventCard extends StatefulWidget {
  const NarrativeEventCard({
    super.key,
    required this.viewModel,
    required this.isHighlighted,
    required this.isFirst,
    required this.isLast,
    required this.otherEvents,
    required this.onSelected,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onEvidenceTap,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onInsertBefore,
    required this.onInsertAfter,
  });

  final NarrativeEventViewModel viewModel;
  final bool isHighlighted;
  final bool isFirst;
  final bool isLast;
  final List<NarrativeEventViewModel> otherEvents;
  final VoidCallback onSelected;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String?> onSummaryChanged;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String> onInsertBefore;
  final ValueChanged<String> onInsertAfter;

  static Key evidenceChipKey(String evidenceId) =>
      Key('reconstruction_evidence_$evidenceId');

  static Key investigatorAddedKey(String eventId) =>
      Key('reconstruction_investigator_added_$eventId');

  @override
  State<NarrativeEventCard> createState() => _NarrativeEventCardState();
}

class _NarrativeEventCardState extends State<NarrativeEventCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.viewModel.event.title);
    _summaryController = TextEditingController(
      text: widget.viewModel.event.summary ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant NarrativeEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel.event.title != widget.viewModel.event.title &&
        _titleController.text != widget.viewModel.event.title) {
      _titleController.text = widget.viewModel.event.title;
    }
    final summary = widget.viewModel.event.summary ?? '';
    if (oldWidget.viewModel.event.summary != widget.viewModel.event.summary &&
        _summaryController.text != summary) {
      _summaryController.text = summary;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _pickRelativeEvent({
    required String title,
    required ValueChanged<String> onSelected,
  }) async {
    if (widget.otherEvents.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(title, style: AppTextStyles.label),
              ),
              for (final event in widget.otherEvents)
                ListTile(
                  title: Text(event.event.title),
                  onTap: () => Navigator.pop(context, event.event.id),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = widget.viewModel.validation;
    final investigatorAdded = widget.viewModel.isInvestigatorAdded;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: InvestigationSelectionVisuals.selectionDuration,
        curve: InvestigationSelectionVisuals.selectionCurve,
        decoration: BoxDecoration(
          color: widget.isHighlighted
              ? InvestigationSelectionVisuals.selectionColor
                  .withValues(alpha: 0.06)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border(
            left: BorderSide(
              color: widget.isHighlighted
                  ? InvestigationSelectionVisuals.selectionColor
                  : AppColors.border,
              width: InvestigationSelectionVisuals.narrativeBorderWidth,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onSelected,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2,
                          right: AppSpacing.xxs,
                        ),
                        child: Text(
                          validation.statusEmoji,
                          style: AppTextStyles.label.copyWith(fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: widget.onTitleChanged,
                          onEditingComplete: () =>
                              widget.onTitleChanged(_titleController.text),
                          onTapOutside: (_) =>
                              widget.onTitleChanged(_titleController.text),
                        ),
                      ),
                      PopupMenuButton<_NarrativeOrderAction>(
                        tooltip: 'Reorder narrative event',
                        onSelected: (action) async {
                          switch (action) {
                            case _NarrativeOrderAction.moveUp:
                              widget.onMoveUp();
                            case _NarrativeOrderAction.moveDown:
                              widget.onMoveDown();
                            case _NarrativeOrderAction.insertBefore:
                              await _pickRelativeEvent(
                                title: 'Insert before',
                                onSelected: widget.onInsertBefore,
                              );
                            case _NarrativeOrderAction.insertAfter:
                              await _pickRelativeEvent(
                                title: 'Insert after',
                                onSelected: widget.onInsertAfter,
                              );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _NarrativeOrderAction.moveUp,
                            enabled: !widget.isFirst,
                            child: const Text('Move Up'),
                          ),
                          PopupMenuItem(
                            value: _NarrativeOrderAction.moveDown,
                            enabled: !widget.isLast,
                            child: const Text('Move Down'),
                          ),
                          const PopupMenuItem(
                            value: _NarrativeOrderAction.insertBefore,
                            child: Text('Insert Before…'),
                          ),
                          const PopupMenuItem(
                            value: _NarrativeOrderAction.insertAfter,
                            child: Text('Insert After…'),
                          ),
                        ],
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (investigatorAdded) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Investigator-added',
                      key: NarrativeEventCard.investigatorAddedKey(
                        widget.viewModel.event.id,
                      ),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxs),
                  NarrativeValidationSummary(validation: validation),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _summaryController,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: NarrativeEvent.maxSummaryLength,
                    buildCounter: (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) =>
                        null,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Optional summary — what happened during this event?',
                      hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      if (value.trim().isEmpty) {
                        widget.onSummaryChanged(null);
                      }
                    },
                    onSubmitted: (value) => widget.onSummaryChanged(
                      value.trim().isEmpty ? null : value.trim(),
                    ),
                    onEditingComplete: () => widget.onSummaryChanged(
                      _summaryController.text.trim().isEmpty
                          ? null
                          : _summaryController.text.trim(),
                    ),
                    onTapOutside: (_) => widget.onSummaryChanged(
                      _summaryController.text.trim().isEmpty
                          ? null
                          : _summaryController.text.trim(),
                    ),
                  ),
                  if (widget.viewModel.hasMissingReferencedEvidence) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.viewModel.referenceStatusMessage ??
                          NarrativeEventViewModel.missingReferenceMessage,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (widget.viewModel.displayEvidence.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SilverLustreText(
                      'Based on captured evidence',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _EvidenceThumbnailRow(
                      evidence: widget.viewModel.displayEvidence,
                      onEvidenceTap: widget.onEvidenceTap,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _NarrativeOrderAction {
  moveUp,
  moveDown,
  insertBefore,
  insertAfter,
}

class _EvidenceThumbnailRow extends StatelessWidget {
  const _EvidenceThumbnailRow({
    required this.evidence,
    required this.onEvidenceTap,
  });

  final List<WorkspaceEvidenceItem> evidence;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;

  static const double _thumbnailSize = 44;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final item in evidence)
          _EvidenceThumbnail(
            item: item,
            onTap: () => onEvidenceTap(item),
          ),
      ],
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({
    required this.item,
    required this.onTap,
  });

  final WorkspaceEvidenceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.kind == WorkspaceEvidenceKind.image ||
            item.kind == WorkspaceEvidenceKind.video ||
            item.kind == WorkspaceEvidenceKind.voice
        ? TimelineEvidenceLabels.capturedLabel(item)
        : TimelineEvidenceLabels.supportingLabel(item);

    return EvidenceReviewHalo(
      evidenceId: item.id,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: NarrativeEventCard.evidenceChipKey(item.id),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              SizedBox(
                width: _EvidenceThumbnailRow._thumbnailSize,
                height: _EvidenceThumbnailRow._thumbnailSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: LivingEvidencePreview(
                      item: item,
                      uniformThumbnailSize: true,
                      suppressBorder: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
