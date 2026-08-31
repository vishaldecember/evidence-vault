import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/workspace_evidence_controller.dart';
import '../../domain/organize/organize_proactive_record.dart';
import '../../models/evidence_record_model.dart';
import '../../models/linked_evidence_item.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../evidence_inspector/evidence_inspector_preview.dart';
import '../evidence_inspector/evidence_spatial_carousel.dart';
import '../evidence_inspector/inspector_atmosphere_background.dart';
import '../linked_evidence/linked_evidence_section.dart';
import 'inspector_context_section.dart';
import 'inspector_record_sections.dart';
import 'inspector_related_person_section.dart';
import 'investigate_incident_scope.dart';

/// Light frosted-glass veil — workspace structure stays readable beneath.
const _backdropBlurSigma = 4.0;

/// Subtle tint over blur; paired with reduced barrier opacity on the route.
const _backdropTintOpacity = 0.08;

/// Cap so the inspector stays a centered panel, not a near-full sheet.
const _modalMaxHeightFactor = 0.78;

/// Navigation affordance for the advanced evidence record.
const _fullRecordActionLabel = 'View complete record →';

/// Comfortable outer margin around the centered inspector.
const _modalOuterMargin = AppSpacing.md;

/// Shows an elevated, blurred inspector over the Incident Workspace.
Future<void> showInvestigationEvidenceInspectorModal({
  required BuildContext context,
  required WorkspaceEvidenceItem evidence,
  required WorkspaceEvidenceController controller,
  List<WorkspaceEvidenceItem>? orderedEvidence,
  String? boundIncidentId,
  Future<void> Function(WorkspaceEvidenceItem evidence)? onOpenAdvancedRecord,
}) {
  final resolvedOrder = orderedEvidence ??
      evidenceInspectorOrder(controller.journeyEvidenceItems);
  final order = resolvedOrder.isEmpty ? [evidence] : resolvedOrder;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Evidence inspector',
    barrierColor: AppColors.navy.withValues(alpha: 0.12),
    transitionDuration: AppMotion.sheet,
    pageBuilder: (context, animation, secondaryAnimation) {
      return InvestigationEvidenceInspectorModal(
        evidence: evidence,
        orderedEvidence: order,
        controller: controller,
        boundIncidentId: boundIncidentId,
        onOpenAdvancedRecord: onOpenAdvancedRecord,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );
      final scale = Tween<double>(
        begin: 0.965,
        end: 1,
      ).animate(curved);

      return Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: curved,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _backdropBlurSigma,
                sigmaY: _backdropBlurSigma,
              ),
              child: ColoredBox(
                color: AppColors.navy.withValues(alpha: _backdropTintOpacity),
              ),
            ),
          ),
          FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        ],
      );
    },
  );
}

class InvestigationEvidenceInspectorModal extends StatefulWidget {
  const InvestigationEvidenceInspectorModal({
    super.key,
    required this.evidence,
    required this.orderedEvidence,
    required this.controller,
    this.boundIncidentId,
    this.onOpenAdvancedRecord,
  });

  /// Debounce for description / note-body autosave.
  @visibleForTesting
  static const Duration persistDebounce = Duration(milliseconds: 400);

  final WorkspaceEvidenceItem evidence;
  final List<WorkspaceEvidenceItem> orderedEvidence;
  final WorkspaceEvidenceController controller;
  final String? boundIncidentId;
  final Future<void> Function(WorkspaceEvidenceItem evidence)?
      onOpenAdvancedRecord;

  @override
  State<InvestigationEvidenceInspectorModal> createState() =>
      _InvestigationEvidenceInspectorModalState();
}

class _InvestigationEvidenceInspectorModalState
    extends State<InvestigationEvidenceInspectorModal> {
  String? _pendingContext;
  String? _pendingNoteBody;
  String? _draftContextNoteId;
  bool _contextEditing = false;
  late int _activeIndex;
  late final String _boundIncidentIdAtOpen;
  Timer? _persistTimer;

  bool get _operationOwnsBound =>
      InvestigateIncidentScope.sessionMatchesBound(
        _boundIncidentIdAtOpen,
        widget.controller.currentIncident.id,
      );

  @override
  void initState() {
    super.initState();
    final bound = widget.boundIncidentId?.trim() ?? '';
    final fromEvidence = widget.evidence.incidentId.trim();
    _boundIncidentIdAtOpen = bound.isNotEmpty
        ? bound
        : (fromEvidence.isNotEmpty
            ? fromEvidence
            : widget.controller.currentIncident.id.trim());
    _activeIndex = _indexForEvidence(widget.evidence.id);
    _draftContextNoteId = _latestContextNoteId();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _persistTimer = null;
    super.dispose();
  }

  int _indexForEvidence(String id) {
    final index = widget.orderedEvidence.indexWhere((item) => item.id == id);
    return index >= 0 ? index : 0;
  }

  WorkspaceEvidenceItem get _activeEvidence {
    final ordered = widget.orderedEvidence;
    if (ordered.isEmpty) {
      return widget.evidence;
    }
    final clamped = _activeIndex.clamp(0, ordered.length - 1);
    return ordered[clamped];
  }

  EvidenceRecordModel get _record {
    final incident = widget.controller.currentIncident;
    final items = widget.controller.sortedItems;
    final active = _activeEvidence;
    final evidence = incident.evidenceById(active.id) ??
        (items.where((e) => e.id == active.id).isEmpty
            ? active
            : items.firstWhere((e) => e.id == active.id));
    return EvidenceRecordModel.fromWorkspace(
      evidence: evidence,
      allItems: items,
      relationships: widget.controller.relationshipRepository.all,
      relationshipGroups: incident.relationshipGroups,
    );
  }

  String? _latestContextNoteId() {
    return InspectorContextSection.editableNote(_record)?.id;
  }

  void _resetDraftState() {
    _pendingContext = null;
    _pendingNoteBody = null;
    _contextEditing = false;
    _draftContextNoteId = _latestContextNoteId();
  }

  void _selectEvidenceIndex(int index) {
    if (index == _activeIndex) {
      return;
    }
    _flushPendingEdits();
    setState(() {
      _activeIndex = index;
      _resetDraftState();
    });
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(
      InvestigationEvidenceInspectorModal.persistDebounce,
      _flushPendingEdits,
    );
  }

  void _handleContextDraft(String text) {
    _pendingContext = text;
    _schedulePersist();
  }

  void _handleNoteBodyChanged(String text) {
    _pendingNoteBody = text;
    _schedulePersist();
  }

  void _flushPendingEdits() {
    _persistTimer?.cancel();
    _persistTimer = null;
    _persistContext();
    _persistNoteBody();
  }

  void _persistContext() {
    final pending = _pendingContext;
    if (pending == null) {
      return;
    }
    if (!_operationOwnsBound) {
      return;
    }

    final trimmed = pending.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final existingId = _draftContextNoteId ?? _latestContextNoteId();
    if (existingId != null) {
      widget.controller.updateEvidenceNoteText(
        evidenceId: existingId,
        text: trimmed,
      );
      _draftContextNoteId = existingId;
    } else {
      _draftContextNoteId = widget.controller.addContextTextNote(
        parentEvidenceId: _activeEvidence.id,
        text: trimmed,
      );
    }
    _pendingContext = null;
  }

  void _persistNoteBody() {
    final noteBody = _pendingNoteBody;
    if (noteBody == null) {
      return;
    }
    if (!_operationOwnsBound) {
      return;
    }
    final active = _activeEvidence;
    if (active.kind != WorkspaceEvidenceKind.note) {
      _pendingNoteBody = null;
      return;
    }
    widget.controller.updateEvidenceNoteText(
      evidenceId: active.id,
      text: noteBody,
    );
    _pendingNoteBody = null;
  }

  void _handleContextEditingChanged(bool editing) {
    if (!editing) {
      _flushPendingEdits();
    }
    if (_contextEditing == editing) {
      return;
    }
    setState(() => _contextEditing = editing);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleClose() {
    _flushPendingEdits();
    _dismissKeyboard();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _handleOpenAdvancedRecord() async {
    final opener = widget.onOpenAdvancedRecord;
    if (opener == null) {
      return;
    }

    _flushPendingEdits();
    final active = _activeEvidence;
    Navigator.of(context).pop();
    await opener(active);
  }

  void _handleLinkedEvidenceTap(LinkedEvidenceItem item) {
    final items = widget.controller.state.items;
    WorkspaceEvidenceItem? linked;
    for (final entry in items) {
      if (entry.id == item.evidenceId) {
        linked = entry;
        break;
      }
    }
    if (linked == null) {
      return;
    }

    final orderIndex =
        widget.orderedEvidence.indexWhere((entry) => entry.id == linked!.id);
    if (orderIndex >= 0) {
      _selectEvidenceIndex(orderIndex);
      return;
    }

    _flushPendingEdits();
    Navigator.of(context).pop();
    showInvestigationEvidenceInspectorModal(
      context: context,
      evidence: linked,
      controller: widget.controller,
      orderedEvidence: widget.orderedEvidence,
      boundIncidentId: _boundIncidentIdAtOpen,
      onOpenAdvancedRecord: widget.onOpenAdvancedRecord,
    );
  }

  Widget _buildHeader() {
    final total = widget.orderedEvidence.isEmpty
        ? 1
        : widget.orderedEvidence.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              'Evidence Inspector',
              style: AppTextStyles.heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                height: 1.15,
                color: AppColors.onCanvas,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          EvidenceInspectorPositionLabel(
            index: _activeIndex,
            total: total,
            color: AppColors.onCanvasSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildViewCompleteRecordAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        0,
      ),
      child: Align(
        alignment: Alignment.center,
        child: TextButton(
          key: const Key('evidence_inspector_open_full_record'),
          onPressed: _handleOpenAdvancedRecord,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.onCanvas,
          ),
          child: Text(
            _fullRecordActionLabel,
            style: AppTextStyles.link.copyWith(
              color: AppColors.onCanvas,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.onCanvas,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onOpenAdvancedRecord != null)
          _buildViewCompleteRecordAction(),
        _buildCloseAction(),
      ],
    );
  }

  Widget _buildCloseAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const Key('evidence_inspector_close'),
          onPressed: _handleClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.navy,
            elevation: 1,
            shadowColor: AppColors.canvasDeep.withValues(alpha: 0.18),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            textStyle: AppTextStyles.button.copyWith(fontSize: 16),
          ),
          child: const Text('Close'),
        ),
      ),
    );
  }

  EvidenceChronologyPosition? _chronologyFor(WorkspaceEvidenceItem evidence) {
    return EvidenceInspectorSemantics.chronologyPosition(
      evidenceId: evidence.id,
      orderedCapturedEvidenceIds:
          widget.controller.timelineRepository.orderedCapturedEvidenceIds(),
    );
  }

  WorkspaceEvidenceItem? _linkedOrganizeMoment(WorkspaceEvidenceItem evidence) {
    String? capturedId;
    for (final item in widget.controller.organizeContextAnchors) {
      if (item.contextEvidenceId == evidence.id) {
        capturedId = item.capturedEvidenceId;
        break;
      }
    }
    if (capturedId == null) {
      return null;
    }
    return widget.controller.currentIncident.evidenceById(capturedId);
  }

  Widget _buildRecordBody(EvidenceRecordModel record) {
    final evidence = widget.controller.currentIncident.evidenceById(
          _activeEvidence.id,
        ) ??
        widget.controller.sortedItems.firstWhere(
          (item) => item.id == _activeEvidence.id,
          orElse: () => _activeEvidence,
        );
    final incidentTitle = widget.controller.currentIncident.title.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorIdentitySection(
          evidence: evidence,
          incidentTitle: incidentTitle,
        ),
        const InspectorQuietDivider(),
        InspectorFactsSection(record: record),
        const InspectorQuietDivider(),
        InspectorIntegritySection(evidence: evidence),
        const InspectorQuietDivider(),
        InspectorProvenanceSection(evidence: evidence),
        if (EvidenceInspectorSemantics.isVaultCapturedMedia(evidence)) ...[
          const InspectorQuietDivider(),
          const InspectorVerificationSection(),
        ],
        const InspectorQuietDivider(),
        if (_linkedOrganizeMoment(evidence) case final linked?) ...[
          InspectorLinkedOrganizeMomentSection(linked: linked),
          const InspectorQuietDivider(),
        ],
        InspectorContextSection(
          key: ValueKey('inspector_context_${record.evidence.id}'),
          record: record,
          onDraftChanged: _handleContextDraft,
          expandEditor: false,
          requestAutofocus: false,
          onEditingChanged: _handleContextEditingChanged,
        ),
        const InspectorQuietDivider(),
        InspectorChronologySection(
          position: _chronologyFor(evidence),
          priorObservationCaption:
              OrganizeProactiveRecord.isPriorObservation(
                item: evidence,
                incidentEvidence: widget.controller.currentIncident.evidence,
              )
                  ? OrganizeProactiveRecord.caption
                  : null,
        ),
        const InspectorQuietDivider(),
        Semantics(
          container: true,
          label:
              '${EvidenceInspectorSemantics.relationshipsHeader}. Connected records, not an AI conclusion.',
          child: Column(
            key: const Key('evidence_inspector_relationships'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InspectorSectionLabel(
                EvidenceInspectorSemantics.relationshipsHeader,
              ),
              const SizedBox(height: 2),
              Text(
                EvidenceInspectorSemantics.relationshipsCaption,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.onCanvasSecondary.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InspectorRelatedPersonSection(
                        key: ValueKey('inspector_related_${evidence.id}'),
                        evidence: evidence,
                        controller: widget.controller,
                        boundIncidentId: _boundIncidentIdAtOpen,
                        onParticipantChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      LinkedEvidenceSection(
                        record: record,
                        sectionTitle: 'Connected evidence',
                        onLinkedEvidenceTap: _handleLinkedEvidenceTap,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Divider(
        key: const Key('evidence_inspector_preview_divider'),
        height: 12,
        thickness: 1,
        color: AppColors.cardHalo.withValues(alpha: 0.55),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    final preventRoutePop = keyboardOpen || _contextEditing;

    return PopScope(
      canPop: !preventRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        _flushPendingEdits();
        if (didPop) {
          return;
        }
        _dismissKeyboard();
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildInspector(context),
      ),
    );
  }

  Widget _buildInspector(BuildContext context) {
    final record = _record;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: AppMotion.sheet,
      curve: AppMotion.enter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_modalOuterMargin),
          child: Align(
            alignment:
                keyboardOpen ? Alignment.bottomCenter : Alignment.center,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final modalMaxHeight = keyboardOpen
                    ? constraints.maxHeight
                    : constraints.maxHeight * _modalMaxHeightFactor;
                final previewHeight = keyboardOpen
                    ? (modalMaxHeight * 0.26).clamp(0.0, 176.0)
                    : (modalMaxHeight * 0.36).clamp(0.0, 260.0);

                return Material(
                  color: Colors.transparent,
                  elevation: 16,
                  shadowColor: AppColors.navy.withValues(alpha: 0.18),
                  clipBehavior: Clip.antiAlias,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      maxHeight: modalMaxHeight,
                    ),
                    child: SizedBox(
                      height: modalMaxHeight,
                      child: DecoratedBox(
                        key: const Key('evidence_inspector_surface'),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.cardRadius),
                          boxShadow: AppDecorations.cardShadows,
                          border: Border.all(
                            color: AppColors.cardHalo.withValues(alpha: 0.55),
                          ),
                        ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const InspectorAtmosphereBackground(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: EvidenceSpatialCarousel(
                              items: widget.orderedEvidence,
                              selectedIndex: _activeIndex,
                              onSelected: _selectEvidenceIndex,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Flexible(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: LayoutBuilder(
                                builder: (context, previewConstraints) {
                                  final height = previewHeight.clamp(
                                    0.0,
                                    previewConstraints.maxHeight,
                                  );
                                  return SizedBox(
                                    height: height,
                                    child: Semantics(
                                      label:
                                          '${record.evidence.kind.label} evidence',
                                      child: EvidenceInspectorPreview(
                                        key: ValueKey(record.evidence.id),
                                        record: record,
                                        onNoteBodyChanged:
                                            _handleNoteBodyChanged,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          _previewDivider(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: SingleChildScrollView(
                                key: const Key(
                                  'evidence_inspector_body_scroll',
                                ),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildRecordBody(record),
                                    const SizedBox(height: AppSpacing.xs),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildFooterActions(),
                        ],
                      ),
                        ],
                      ),
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

