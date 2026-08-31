import 'package:flutter/material.dart';



import '../constants/app_spacing.dart';

import '../models/evidence_record_model.dart';

import '../models/evidence_relationship.dart';

import '../models/linked_evidence_item.dart';

import '../models/relationship_group.dart';

import '../models/workspace_capture_mode.dart';

import '../models/workspace_evidence_item.dart';

import '../navigation/app_navigation.dart';

import '../theme/app_colors.dart';

import '../theme/app_text_styles.dart';

import '../widgets/common/app_back_button.dart';

import '../theme/app_motion.dart';

import '../widgets/evidence_record/evidence_record_galaxy_background.dart';

import '../widgets/context/context_section_card.dart';

import '../widgets/evidence_record/evidence_record_evidence_section.dart';

import '../widgets/evidence_record/evidence_record_metadata_section.dart';

import '../widgets/trust/trust_summary_section.dart';

import '../widgets/linked_evidence/linked_evidence_section.dart';



/// Lightweight inspection screen for one preserved Evidence Artifact.

///

/// View evidence, add context, inspect linked evidence, metadata, and

/// verification. Relationship editing belongs in the Connections Workspace only.

class EvidenceRecordScreen extends StatefulWidget {

  const EvidenceRecordScreen({

    super.key,

    required this.evidenceId,

    required this.getItems,

    required this.getRelationships,

    this.getRelationshipGroups,

    required this.onAddContext,

    this.onAddContextText,

  });



  final String evidenceId;

  final List<WorkspaceEvidenceItem> Function() getItems;

  final List<EvidenceRelationship> Function() getRelationships;

  final List<RelationshipGroup> Function()? getRelationshipGroups;

  final void Function(String evidenceId, WorkspaceCaptureMode mode) onAddContext;

  final void Function(String evidenceId, String text)? onAddContextText;



  @override

  State<EvidenceRecordScreen> createState() => _EvidenceRecordScreenState();

}



class _EvidenceRecordScreenState extends State<EvidenceRecordScreen> {

  final GlobalKey _contextSectionKey = GlobalKey();



  EvidenceRecordModel get _record {

    final items = widget.getItems();

    final evidence = items.firstWhere((item) => item.id == widget.evidenceId);

    return EvidenceRecordModel.fromWorkspace(

      evidence: evidence,

      allItems: items,

      relationships: widget.getRelationships(),

      relationshipGroups: widget.getRelationshipGroups?.call() ?? const [],

    );

  }



  void _handleContextTextSubmitted(String text) {

    final handler = widget.onAddContextText;

    if (handler != null) {

      handler(widget.evidenceId, text);

    } else {

      widget.onAddContext(widget.evidenceId, WorkspaceCaptureMode.note);

    }

    setState(() {});

  }



  void _handleContextReminderExpanded() {

    WidgetsBinding.instance.addPostFrameCallback((_) {

      final sectionContext = _contextSectionKey.currentContext;

      if (sectionContext != null && sectionContext.mounted) {

        Scrollable.ensureVisible(

          sectionContext,

          duration: AppMotion.medium,

          curve: AppMotion.enter,

          alignment: 0.1,

        );

      }

    });

  }



  void _openLinkedRecord(LinkedEvidenceItem item) {

    AppNavigation.openEvidenceRecord(

      context,

      evidenceId: item.evidenceId,

      getItems: widget.getItems,

      getRelationships: widget.getRelationships,

      getRelationshipGroups: widget.getRelationshipGroups,

      onAddContext: widget.onAddContext,

      onAddContextText: widget.onAddContextText,

    );

  }



  @override

  Widget build(BuildContext context) {

    final record = _record;

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;



    return Stack(

      fit: StackFit.expand,

      children: [

        const EvidenceRecordGalaxyBackground(),

        Scaffold(

      backgroundColor: Colors.transparent,

      appBar: AppBar(

        backgroundColor: Colors.transparent,

        foregroundColor: AppColors.onCanvas,

        elevation: 0,

        scrolledUnderElevation: 0,

        leading: const AppBackButton(color: AppColors.onCanvas),

        title: Text(

          'Evidence Record',

          style: AppTextStyles.screenTitle.copyWith(color: AppColors.onCanvas),

        ),

      ),

      body: SafeArea(

        top: false,

        child: SingleChildScrollView(

          padding: EdgeInsets.fromLTRB(

            AppSpacing.screenHorizontal,

            AppSpacing.sm,

            AppSpacing.screenHorizontal,

            AppSpacing.md + bottomInset,

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              EvidenceRecordEvidenceSection(record: record),

              const SizedBox(height: AppSpacing.md),

              ContextSectionCard(

                sectionKey: _contextSectionKey,

                record: record,

                allItems: widget.getItems(),

                relationships: widget.getRelationships(),

                onExpanded: _handleContextReminderExpanded,

                onContextTextSubmitted: _handleContextTextSubmitted,

              ),

              const SizedBox(height: AppSpacing.md),

              LinkedEvidenceSection(

                record: record,

                onLinkedEvidenceTap: _openLinkedRecord,

              ),

              const SizedBox(height: AppSpacing.md),

              EvidenceRecordMetadataSection(record: record),

              const SizedBox(height: AppSpacing.md),

              TrustSummarySection(record: record),

            ],

          ),

        ),

      ),

    ),

      ],

    );

  }

}


