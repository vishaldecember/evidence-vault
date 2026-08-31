import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_bottom_sheet.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// Opens a read-only Evidence Detail sheet — evidence is immutable.
Future<void> showEvidenceDetailSheet({
  required BuildContext context,
  required WorkspaceEvidenceItem evidence,
  required ValueChanged<WorkspaceCaptureMode> onAddContext,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (context) {
      return EvidenceDetailSheet(
        evidence: evidence,
        onAddContext: (mode) {
          Navigator.pop(context);
          onAddContext(mode);
        },
      );
    },
  );
}

class EvidenceDetailSheet extends StatefulWidget {
  const EvidenceDetailSheet({
    super.key,
    required this.evidence,
    required this.onAddContext,
  });

  final WorkspaceEvidenceItem evidence;
  final ValueChanged<WorkspaceCaptureMode> onAddContext;

  @override
  State<EvidenceDetailSheet> createState() => _EvidenceDetailSheetState();
}

class _EvidenceDetailSheetState extends State<EvidenceDetailSheet> {
  bool _showAddContext = false;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Evidence', style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  widget.evidence.title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _EvidencePreview(evidence: widget.evidence),
                const SizedBox(height: AppSpacing.lg),
                _MetadataSection(evidence: widget.evidence),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _showAddContext = !_showAddContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 2,
                      shadowColor: AppColors.primaryShadow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text('Add Context', style: AppTextStyles.button),
                  ),
                ),
                if (_showAddContext) ...[
                  const SizedBox(height: AppSpacing.md),
                  const AddContextActions(),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final mode in WorkspaceCaptureMode.values)
                        _AddContextChip(
                          mode: mode,
                          onTap: () => widget.onAddContext(mode),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({required this.evidence});

  final WorkspaceEvidenceItem evidence;

  static double _preferredHeight(WorkspaceEvidenceKind kind) => switch (kind) {
        WorkspaceEvidenceKind.image => 200,
        WorkspaceEvidenceKind.video => 150,
        WorkspaceEvidenceKind.voice => 88,
        WorkspaceEvidenceKind.attachment => 96,
        WorkspaceEvidenceKind.note => 130,
        WorkspaceEvidenceKind.witness => 120,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidence Preview', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: SizedBox(
            height: _preferredHeight(evidence.kind),
            width: double.infinity,
            child: _DetailPreviewContent(evidence: evidence),
          ),
        ),
      ],
    );
  }
}

class _DetailPreviewContent extends StatelessWidget {
  const _DetailPreviewContent({required this.evidence});

  final WorkspaceEvidenceItem evidence;

  @override
  Widget build(BuildContext context) {
    return switch (evidence.kind) {
      WorkspaceEvidenceKind.image => Container(
          color: AppColors.surfaceMuted,
          child: const Center(
            child: Icon(Icons.image_outlined, size: 64, color: AppColors.primary),
          ),
        ),
      WorkspaceEvidenceKind.video => Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surfaceMuted),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.onPrimary,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      WorkspaceEvidenceKind.voice => Container(
          color: AppColors.surfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              IconButton.filled(
                onPressed: null,
                icon: const Icon(Icons.play_arrow_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final height in [
                      14.0, 28.0, 18.0, 32.0, 20.0, 26.0, 16.0, 24.0, 18.0,
                    ])
                      Container(
                        width: 3.5,
                        height: height,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Voice note',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      WorkspaceEvidenceKind.note => Container(
          color: AppColors.surfaceMuted,
          padding: const EdgeInsets.all(AppSpacing.md),
          alignment: Alignment.topLeft,
          child: Text(
            evidence.notePreview ??
                'Observed the interaction at the entrance.\n'
                    'Timestamp aligns with prior evidence.',
            style: AppTextStyles.body.copyWith(fontSize: 15, height: 1.5),
          ),
        ),
      WorkspaceEvidenceKind.attachment => Container(
          color: AppColors.surfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evidence.fileName ?? 'Attachment',
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Document',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      WorkspaceEvidenceKind.witness => Container(
          color: AppColors.surfaceMuted,
          child: const Center(
            child: Icon(Icons.person_outline, size: 64, color: AppColors.primary),
          ),
        ),
    };
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.evidence});

  final WorkspaceEvidenceItem evidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evidence Metadata', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          _MetadataRow(
            label: 'Evidence',
            value: evidence.kind.label,
          ),
          _MetadataRow(
            label: 'Last Preserved',
            value: WorkspaceEvidenceFormatters.lastPreserved(
              evidence.lastPreservedAt,
            ),
          ),
          _MetadataRow(
            label: 'Integrity Verified',
            value: evidence.integrityVerified ? '✓' : '—',
            valueColor: evidence.integrityVerified ? AppColors.success : null,
          ),
          if (evidence.relatedEvidenceIds.isNotEmpty)
            _MetadataRow(
              label: 'Relationship',
              value: '${evidence.relatedEvidenceIds.length} connected',
            ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.label.copyWith(
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddContextActions extends StatelessWidget {
  const AddContextActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Context creates new evidence. Original evidence remains unchanged.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _AddContextChip extends StatelessWidget {
  const _AddContextChip({
    required this.mode,
    required this.onTap,
  });

  final WorkspaceCaptureMode mode;
  final VoidCallback onTap;

  String get _label => switch (mode) {
        WorkspaceCaptureMode.photo => 'Photo',
        WorkspaceCaptureMode.video => 'Video',
        WorkspaceCaptureMode.voice => 'Voice Note',
        WorkspaceCaptureMode.note => 'Note',
        WorkspaceCaptureMode.file => 'Attachment',
      };

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(mode.icon, size: 18, color: AppColors.primary),
      label: Text(_label),
      labelStyle: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
      backgroundColor: AppColors.surfaceMuted,
      side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      onPressed: onTap,
    );
  }
}
