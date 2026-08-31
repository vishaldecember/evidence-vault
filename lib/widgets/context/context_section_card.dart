import 'package:flutter/material.dart';



import '../../constants/app_spacing.dart';

import '../../engines/enrichment_engine.dart';

import '../../models/evidence_record_model.dart';

import '../../models/evidence_relationship.dart';

import '../../models/workspace_evidence_item.dart';

import '../../theme/app_colors.dart';

import '../../theme/app_decorations.dart';

import 'context_reminder_drawer.dart';

import 'context_timeline_section.dart';



/// Context card with optional enrichment reminder and always-on composer.

class ContextSectionCard extends StatefulWidget {

  const ContextSectionCard({
    super.key,
    required this.record,
    required this.allItems,
    required this.relationships,
    this.sectionKey,
    this.onExpanded,
    this.onContextTextSubmitted,
    this.requestComposerFocusOnOpen = true,
    this.composerAutofocus = true,
    this.compactLayout = false,
    this.composerMinLines = 3,
  });

  final EvidenceRecordModel record;
  final List<WorkspaceEvidenceItem> allItems;
  final List<EvidenceRelationship> relationships;
  final GlobalKey? sectionKey;
  final VoidCallback? onExpanded;
  final ValueChanged<String>? onContextTextSubmitted;
  final bool requestComposerFocusOnOpen;
  final bool composerAutofocus;
  final bool compactLayout;
  final int composerMinLines;



  @override

  State<ContextSectionCard> createState() => _ContextSectionCardState();

}



class _ContextSectionCardState extends State<ContextSectionCard> {

  bool _reminderExpanded = false;

  final FocusNode _composerFocusNode = FocusNode();



  @override

  void initState() {

    super.initState();

    if (widget.requestComposerFocusOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _composerFocusNode.requestFocus();
      });
    }
  }



  @override

  void dispose() {

    _composerFocusNode.dispose();

    super.dispose();

  }



  bool get _showReminder {

    if (!EnrichmentEngine.isPrimaryEvidence(widget.record.evidence)) {

      return false;

    }



    return !EnrichmentEngine.isEnriched(

      widget.record.evidence,

      EnrichmentContext(

        items: widget.allItems,

        relationships: widget.relationships,

      ),

    );

  }



  void _toggleReminder() {

    setState(() => _reminderExpanded = !_reminderExpanded);

    if (_reminderExpanded) {

      widget.onExpanded?.call();

    }

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!mounted) {

        return;

      }

      _composerFocusNode.requestFocus();

    });

  }



  void _handleContextSubmit(String text) {

    widget.onContextTextSubmitted?.call(text);

  }



  @override

  Widget build(BuildContext context) {

    final showComposer = widget.onContextTextSubmitted != null;



    return Container(

      key: widget.sectionKey,

      clipBehavior: Clip.hardEdge,

      decoration: BoxDecoration(

        color: AppColors.background,

        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),

        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),

        boxShadow: AppDecorations.captureLayerShadows,

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          if (_showReminder && !widget.compactLayout)

            ContextReminderDrawer(

              isExpanded: _reminderExpanded,

              onToggle: _toggleReminder,

            ),

          Padding(

            padding: EdgeInsets.all(
              widget.compactLayout ? AppSpacing.sm : AppSpacing.md,
            ),

            child: ContextTimelineSection(
              record: widget.record,
              showHeader: true,
              showComposer: showComposer,
              composerFocusNode: _composerFocusNode,
              composerAutofocus: widget.composerAutofocus,
              composerMinLines: widget.composerMinLines,
              compactEmptyState: widget.compactLayout,
              onContextTextSubmitted: showComposer ? _handleContextSubmit : null,
            ),

          ),

        ],

      ),

    );

  }

}


