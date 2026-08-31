import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/context_item.dart';
import '../../models/evidence_record_model.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';
import 'context_inline_composer.dart';
import 'context_item_card.dart';

/// Pillar 3 — Context Timeline
///
/// Answers: "What helps me understand it?"
/// Newest context appears first. Extension points reserved for witness
/// statements, location confirmations, relationships, AI observations,
/// and reflection.
class ContextTimelineSection extends StatelessWidget {
  const ContextTimelineSection({
    super.key,
    required this.record,
    this.showHeader = true,
    this.sectionKey,
    this.showComposer = false,
    this.composerFocusNode,
    this.composerAutofocus = false,
    this.composerMinLines = 3,
    this.compactEmptyState = false,
    this.onContextTextSubmitted,
  });

  final EvidenceRecordModel record;
  final bool showHeader;
  final GlobalKey? sectionKey;
  final bool showComposer;
  final FocusNode? composerFocusNode;
  final bool composerAutofocus;
  final int composerMinLines;
  final bool compactEmptyState;
  final ValueChanged<String>? onContextTextSubmitted;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          const WorkspaceSectionHeader(
            title: EvidenceInspectorSemantics.observationsHeader,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (record.hasContext) ...[
          _Timeline(items: record.contextItems),
          if (showComposer &&
              composerFocusNode != null &&
              onContextTextSubmitted != null) ...[
            const SizedBox(height: AppSpacing.md),
            ContextInlineComposer(
              focusNode: composerFocusNode!,
              autofocus: composerAutofocus,
              minLines: composerMinLines,
              maxLines: composerMinLines + 1,
              onSubmit: onContextTextSubmitted!,
            ),
          ],
        ] else if (showComposer &&
            composerFocusNode != null &&
            onContextTextSubmitted != null)
          ContextInlineComposer(
            focusNode: composerFocusNode!,
            autofocus: composerAutofocus,
            minLines: composerMinLines,
            maxLines: composerMinLines + 1,
            onSubmit: onContextTextSubmitted!,
          )
        else if (compactEmptyState)
          const SizedBox.shrink()
        else
          _EmptyState(),
      ],
    );

    if (sectionKey != null && showHeader) {
      return WorkspaceCard(
        key: sectionKey,
        child: content,
      );
    }

    if (showHeader) {
      return WorkspaceCard(child: content);
    }

    return content;
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No additional context yet.',
          style: AppTextStyles.bodySmall.copyWith(height: 1.5),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Every piece of context helps build a richer understanding '
          'without changing the preserved evidence.',
          style: AppTextStyles.caption.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});

  final List<ContextItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          ContextItemCard(
            item: items[i],
            showDivider: i < items.length - 1,
          ),
      ],
    );
  }
}
