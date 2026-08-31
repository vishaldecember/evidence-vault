import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../engines/narrative_builder.dart';
import '../../../models/workspace_evidence_item.dart';
import '../../../services/narrative_validation_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'narrative_builder_header.dart';
import 'narrative_event_card.dart';

/// Structured Narrative Builder with live projection and audit-friendly ordering.
class StructuredNarrativeBuilder extends StatelessWidget {
  const StructuredNarrativeBuilder({
    super.key,
    required this.incidentName,
    required this.events,
    required this.timelineAnchorCount,
    required this.relationshipGroupCount,
    required this.highlightedEventIds,
    required this.onEventSelected,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onEvidenceTap,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onInsertBefore,
    required this.onInsertAfter,
    this.showHeader = true,
  });

  final String incidentName;
  final List<NarrativeEventViewModel> events;
  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final Set<String> highlightedEventIds;
  final ValueChanged<NarrativeEventViewModel> onEventSelected;
  final void Function(String eventId, String title) onTitleChanged;
  final void Function(String eventId, String? summary) onSummaryChanged;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;
  final ValueChanged<String> onMoveUp;
  final ValueChanged<String> onMoveDown;
  final void Function(String eventId, String relativeEventId) onInsertBefore;
  final void Function(String eventId, String relativeEventId) onInsertAfter;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Capture primary evidence to begin reconstructing what happened.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final reconstructionHealth =
        NarrativeValidationService.computeReconstructionHealth(
      events.map((event) => event.validation).toList(growable: false),
    );

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: showHeader ? events.length + 1 : events.length,
      separatorBuilder: (context, index) {
        if (showHeader && index == 0) {
          return const SizedBox.shrink();
        }
        return const SizedBox(height: AppSpacing.sm);
      },
      itemBuilder: (context, index) {
        if (showHeader && index == 0) {
          return NarrativeBuilderHeader(
            incidentName: incidentName,
            narrativeEventCount: events.length,
            timelineAnchorCount: timelineAnchorCount,
            relationshipGroupCount: relationshipGroupCount,
            reconstructionHealth: reconstructionHealth,
          );
        }

        final eventIndex = showHeader ? index - 1 : index;
        final viewModel = events[eventIndex];
        return NarrativeEventCard(
          key: ValueKey(viewModel.event.id),
          viewModel: viewModel,
          isHighlighted: highlightedEventIds.contains(viewModel.event.id),
          isFirst: eventIndex == 0,
          isLast: eventIndex == events.length - 1,
          otherEvents: [
            for (final other in events)
              if (other.event.id != viewModel.event.id) other,
          ],
          onSelected: () => onEventSelected(viewModel),
          onTitleChanged: (title) =>
              onTitleChanged(viewModel.event.id, title),
          onSummaryChanged: (summary) =>
              onSummaryChanged(viewModel.event.id, summary),
          onEvidenceTap: onEvidenceTap,
          onMoveUp: () => onMoveUp(viewModel.event.id),
          onMoveDown: () => onMoveDown(viewModel.event.id),
          onInsertBefore: (relativeEventId) => onInsertBefore(
            viewModel.event.id,
            relativeEventId,
          ),
          onInsertAfter: (relativeEventId) => onInsertAfter(
            viewModel.event.id,
            relativeEventId,
          ),
        );
      },
    );
  }
}
