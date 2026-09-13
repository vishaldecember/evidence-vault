import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/reflection_model.dart';
import '../models/temporary_relationship_group.dart';
import '../models/workspace_capture_mode.dart';
import '../models/workspace_evidence_item.dart';
import '../navigation/app_navigation.dart';
import '../navigation/app_navigator.dart';
import '../screens/capture/capture_cockpit_screen.dart';
import '../services/storage/capture_media_service.dart';
import '../services/storage/file_attach_flow.dart';
import '../widgets/capture/text_note_capture_sheet.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/reflection/reflection_editor_sheet.dart';
import '../widgets/investigation/investigate_incident_scope.dart';
import '../widgets/workspace/organize_workspace_view.dart';
import '../widgets/workspace/workspace_body.dart';
import '../widgets/workspace/workspace_body_presentation.dart';

/// Capture and Evidence stage bodies hosted inside [IncidentWorkspaceShell].
class EvidenceWorkspaceContent extends StatefulWidget {
  const EvidenceWorkspaceContent({
    super.key,
    required this.controller,
    required this.boundIncidentId,
    required this.presentation,
    required this.onShowEvidenceInspector,
    this.initialCaptureMode,
    this.onEnterInvestigation,
    this.buildFileAttachWorkspace,
    this.onGroupCompositionChanged,
  });

  final WorkspaceEvidenceController controller;

  /// Shell-authoritative incident. Session controller is subordinate.
  final String boundIncidentId;
  final WorkspaceBodyPresentation presentation;
  final Future<void> Function(WorkspaceEvidenceItem) onShowEvidenceInspector;
  final WorkspaceCaptureMode? initialCaptureMode;
  final VoidCallback? onEnterInvestigation;

  /// Restores Organize after SAF if this State's route was torn down.
  final Widget Function()? buildFileAttachWorkspace;
  final ValueChanged<bool>? onGroupCompositionChanged;

  static Future<void> openEvidenceRecord({
    required BuildContext context,
    required WorkspaceEvidenceController controller,
    required WorkspaceEvidenceItem evidence,
    required VoidCallback onStateChanged,
    required String boundIncidentId,
  }) {
    bool sessionMatchesBound() => InvestigateIncidentScope.sessionMatchesBound(
      boundIncidentId,
      controller.currentIncident.id,
    );
    return AppNavigation.openEvidenceRecord(
      context,
      evidenceId: evidence.id,
      getItems: () => controller.sortedItems,
      getRelationships: () => controller.relationshipRepository.all,
      getRelationshipGroups: () => controller.state.relationshipGroups,
      onAddContext: (evidenceId, mode) {
        if (!sessionMatchesBound()) {
          return;
        }
        controller.addContextEvidence(parentEvidenceId: evidenceId, mode: mode);
        onStateChanged();
        AppSnackBar.showSuccess(
          context,
          'Relationship created. Context preserved.',
        );
      },
      onAddContextText: (evidenceId, text) {
        if (!sessionMatchesBound()) {
          return;
        }
        controller.addContextTextNote(parentEvidenceId: evidenceId, text: text);
        onStateChanged();
      },
    ).then((_) => onStateChanged());
  }

  @override
  State<EvidenceWorkspaceContent> createState() =>
      EvidenceWorkspaceContentState();
}

class EvidenceWorkspaceContentState extends State<EvidenceWorkspaceContent> {
  WorkspaceCaptureMode? _activeCaptureMode;
  String? _animateEvidenceId;
  bool _initialCaptureHandled = false;
  bool _connectModeActive = false;
  TemporaryRelationshipGroup _pendingGroup = const TemporaryRelationshipGroup();
  bool _collectionsEnsured = false;

  WorkspaceEvidenceController get _controller => widget.controller;

  bool get _sessionMatchesBound => InvestigateIncidentScope.sessionMatchesBound(
    widget.boundIncidentId,
    _controller.currentIncident.id,
  );

  @override
  void initState() {
    super.initState();
    _pendingGroup = TemporaryRelationshipGroup.initial(
      _controller.state.relationshipGroups,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _captureInitialEvidenceIfNeeded();
      _ensureCollectionsIfOrganize();
    });
  }

  @override
  void didUpdateWidget(covariant EvidenceWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation != widget.presentation) {
      _collectionsEnsured = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _ensureCollectionsIfOrganize();
      });
    }
  }

  void _ensureCollectionsIfOrganize() {
    if (!_sessionMatchesBound || !_isEvidenceStage || _collectionsEnsured) {
      return;
    }
    _collectionsEnsured = true;
    _controller.ensureEvidenceCollections();
  }

  void _captureInitialEvidenceIfNeeded() {
    if (_initialCaptureHandled ||
        widget.presentation != WorkspaceBodyPresentation.capture) {
      return;
    }
    final mode = widget.initialCaptureMode;
    if (mode == null) {
      return;
    }
    if (!_sessionMatchesBound || _controller.isArchivedReadOnly) {
      return;
    }
    _initialCaptureHandled = true;
    // Seed CurrentIncident on the post-mount frame so ListenableBuilder /
    // Incident Journey can rebuild without opening Capture Cockpit. Home
    // Capture Now and the sticky bar still own cockpit navigation.
    final newId = _isFlutterTest
        ? _controller.preserveForWidgetTest(mode)
        : _controller.preserveEvidenceAndReturnId(mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _activeCaptureMode = mode;
      _animateEvidenceId = newId;
    });
  }

  bool get _isEvidenceStage =>
      widget.presentation == WorkspaceBodyPresentation.evidence;

  void _handleCaptureModeSelected(WorkspaceCaptureMode mode) {
    if (!_sessionMatchesBound || _connectModeActive) {
      return;
    }
    if (_controller.isArchivedReadOnly) {
      AppSnackBar.showSuccess(
        context,
        'Restore this incident to make changes.',
      );
      return;
    }
    _runCapture(mode);
  }

  Future<void> _addOrganizeContext(WorkspaceCaptureMode mode) async {
    if (!_sessionMatchesBound || _controller.isArchivedReadOnly) {
      return;
    }
    if (mode != WorkspaceCaptureMode.voice &&
        mode != WorkspaceCaptureMode.note &&
        mode != WorkspaceCaptureMode.file) {
      return;
    }

    if (_isFlutterTest) {
      _controller.addOrganizeContextEvidence(mode);
      return;
    }

    if (mode == WorkspaceCaptureMode.note) {
      final text = await TextNoteCaptureSheet.open(context);
      if (!mounted || text == null || text.trim().isEmpty) {
        return;
      }
      final id = await _controller.preserveTextNote(text);
      _controller.registerOrganizeCreatedEvidence(id);
      return;
    }

    if (mode == WorkspaceCaptureMode.voice) {
      final before = {
        for (final item in _controller.currentIncident.evidence) item.id,
      };
      await CaptureCockpitScreen.open(
        context,
        initialMode: mode,
        controller: _controller,
        boundIncidentId: widget.boundIncidentId,
      );
      if (!mounted) {
        return;
      }
      for (final item in _controller.currentIncident.evidence) {
        if (!before.contains(item.id)) {
          _controller.registerOrganizeCreatedEvidence(item.id);
        }
      }
      return;
    }

    // File — session-scoped SAF attach. Must not abort on !mounted after
    // picker return; that dropped the selected file and surfaced Home.
    final before = {
      for (final item in _controller.currentIncident.evidence) item.id,
    };
    try {
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: mounted ? context : null,
        asOrganizeContext: true,
        buildWorkspace:
            widget.buildFileAttachWorkspace ?? () => const SizedBox.shrink(),
      );
      FileAttachFlow.markOrganizeCreatedSince(before);
      if (result.outcome == FileAttachOutcome.failed) {
        final msg =
            result.userMessage ?? 'Couldn’t attach that file. Try again.';
        final snackCtx = mounted ? context : appNavigatorKey.currentContext;
        if (snackCtx != null && snackCtx.mounted) {
          AppSnackBar.showError(snackCtx, msg);
        }
      }
    } catch (_) {
      final snackCtx = mounted ? context : appNavigatorKey.currentContext;
      if (snackCtx != null && snackCtx.mounted) {
        AppSnackBar.showError(
          snackCtx,
          'Couldn’t attach that file. Try again.',
        );
      }
    }
  }

  /// Widget tests have no camera/mic — keep mock preserve so journey UI asserts.
  bool get _isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  bool _operationOwnsBound(String boundIncidentIdAtStart) {
    return InvestigateIncidentScope.sessionMatchesBound(
      boundIncidentIdAtStart,
      _controller.currentIncident.id,
    );
  }

  Future<void> _runCapture(WorkspaceCaptureMode mode) async {
    final boundIncidentIdAtStart = widget.boundIncidentId;
    if (!_operationOwnsBound(boundIncidentIdAtStart)) {
      return;
    }

    // Widget tests have no camera/mic. Preserve through CurrentIncident so
    // Incident Journey can rebuild on the next pump — same shared collection
    // as production, without opening Capture Cockpit. Note uses the compact
    // editor sheet (production), whose title is the journey "Text Note" cue.
    if (_isFlutterTest) {
      if (mode == WorkspaceCaptureMode.photo ||
          mode == WorkspaceCaptureMode.video ||
          mode == WorkspaceCaptureMode.voice ||
          mode == WorkspaceCaptureMode.file) {
        if (!_operationOwnsBound(boundIncidentIdAtStart)) {
          return;
        }
        final newId = _controller.preserveForWidgetTest(mode);
        if (!mounted || !_operationOwnsBound(boundIncidentIdAtStart)) {
          return;
        }
        setState(() {
          _activeCaptureMode = mode;
          _animateEvidenceId = newId;
        });
        AppSnackBar.showSuccess(context, 'Evidence preserved.');
        return;
      }
    }

    // Text Note — compact editor; never silent-create / auto-attach to voice.
    if (mode == WorkspaceCaptureMode.note) {
      final text = await TextNoteCaptureSheet.open(context);
      if (!mounted || text == null || text.trim().isEmpty) {
        return;
      }
      if (!_operationOwnsBound(boundIncidentIdAtStart)) {
        return;
      }
      final newId = await _controller.preserveTextNote(text);
      if (!mounted || !_operationOwnsBound(boundIncidentIdAtStart)) {
        return;
      }
      setState(() {
        _activeCaptureMode = mode;
        _animateEvidenceId = newId;
      });
      AppSnackBar.showSuccess(context, 'Text note preserved.');
      return;
    }

    // Photo / Video / Voice → Capture Cockpit (canonical). Do not open the
    // legacy standalone ContinuousCaptureSession route from Workspace capture.
    if (mode == WorkspaceCaptureMode.photo ||
        mode == WorkspaceCaptureMode.video ||
        mode == WorkspaceCaptureMode.voice) {
      if (!_operationOwnsBound(boundIncidentIdAtStart)) {
        return;
      }
      await CaptureCockpitScreen.open(
        context,
        initialMode: mode,
        controller: _controller,
        boundIncidentId: boundIncidentIdAtStart,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeCaptureMode = mode;
        _animateEvidenceId = null;
      });
      return;
    }

    await attachCaptureFile();
  }

  /// Canonical File attach for shell Capture. Same [FileAttachFlow.attach]
  /// transaction as Workspace sticky File. Does not mint a new incident.
  @visibleForTesting
  Future<FileAttachResult> attachCaptureFile({
    Future<CapturedMediaFile?> Function()? acquireFile,
  }) async {
    final boundIncidentIdAtStart = widget.boundIncidentId;
    final sourceIncidentId = _controller.currentIncident.id;
    try {
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: mounted ? context : null,
        buildWorkspace:
            widget.buildFileAttachWorkspace ?? () => const SizedBox.shrink(),
        acquireFile: acquireFile,
      );
      if (result.outcome == FileAttachOutcome.failed) {
        final msg =
            result.userMessage ?? 'Couldn’t attach that file. Try again.';
        final snackCtx = mounted ? context : appNavigatorKey.currentContext;
        if (snackCtx != null && snackCtx.mounted) {
          AppSnackBar.showError(snackCtx, msg);
        }
      } else if (result.outcome == FileAttachOutcome.succeeded &&
          mounted &&
          _operationOwnsBound(boundIncidentIdAtStart)) {
        setState(() {
          _activeCaptureMode = WorkspaceCaptureMode.file;
          _animateEvidenceId = result.evidenceId;
        });
      }
      assert(
        result.sourceIncidentId == sourceIncidentId ||
            result.outcome != FileAttachOutcome.succeeded,
        'Capture File must keep the same incident',
      );
      return result;
    } catch (_) {
      final snackCtx = mounted ? context : appNavigatorKey.currentContext;
      if (snackCtx != null && snackCtx.mounted) {
        AppSnackBar.showError(
          snackCtx,
          'Couldn’t attach that file. Try again.',
        );
      }
      return FileAttachResult(
        outcome: FileAttachOutcome.failed,
        sourceIncidentId: sourceIncidentId,
        userMessage: 'Couldn’t attach that file. Try again.',
      );
    }
  }

  void _cancelConnectMode() {
    setState(() {
      _connectModeActive = false;
      _pendingGroup = TemporaryRelationshipGroup.initial(
        _controller.state.relationshipGroups,
      );
    });
  }

  void _handleJourneyEvidenceTap(WorkspaceEvidenceItem evidence) {
    if (!_connectModeActive) {
      widget.onShowEvidenceInspector(evidence);
      return;
    }

    setState(() {
      _pendingGroup = _pendingGroup.toggle(evidence.id);
    });
  }

  void _openAddReflection() {
    final boundIncidentIdAtStart = widget.boundIncidentId;
    if (!_operationOwnsBound(boundIncidentIdAtStart) ||
        _controller.isArchivedReadOnly) {
      return;
    }
    showReflectionEditorSheet(
      context: context,
      onSave: ({String? title, required String body}) {
        if (!_operationOwnsBound(boundIncidentIdAtStart)) {
          return;
        }
        applyAddReflection(title: title, body: body);
      },
    );
  }

  void _openEditReflection(ReflectionModel reflection) {
    final boundIncidentIdAtStart = widget.boundIncidentId;
    if (!_operationOwnsBound(boundIncidentIdAtStart) ||
        _controller.isArchivedReadOnly) {
      return;
    }
    showReflectionEditorSheet(
      context: context,
      existing: reflection,
      onSave: ({String? title, required String body}) {
        if (!_operationOwnsBound(boundIncidentIdAtStart)) {
          return;
        }
        applyEditReflection(
          reflectionId: reflection.id,
          title: title,
          body: body,
        );
      },
    );
  }

  @visibleForTesting
  void applyAddReflection({String? title, required String body}) {
    if (!_operationOwnsBound(widget.boundIncidentId)) {
      return;
    }
    setState(() {
      _controller.addReflection(title: title, body: body);
    });
    AppSnackBar.showSuccess(context, 'Reflection preserved.');
  }

  @visibleForTesting
  void applyEditReflection({
    required String reflectionId,
    String? title,
    required String body,
  }) {
    if (!_operationOwnsBound(widget.boundIncidentId)) {
      return;
    }
    setState(() {
      _controller.updateReflection(
        reflectionId: reflectionId,
        title: title,
        body: body,
      );
    });
  }

  void _handleIncidentNameChanged(String name) {
    if (!_operationOwnsBound(widget.boundIncidentId) ||
        _controller.isArchivedReadOnly) {
      return;
    }
    _controller.updateIncidentName(name);
  }

  Future<void> _createGroup() async {
    final boundIncidentIdAtStart = widget.boundIncidentId;
    if (!_operationOwnsBound(boundIncidentIdAtStart)) {
      return;
    }
    final selectedIds = await _pickEvidenceForNewGroup();
    if (selectedIds == null || selectedIds.length < 2) {
      return;
    }
    if (!_operationOwnsBound(boundIncidentIdAtStart)) {
      return;
    }
    _controller.createUserEvidenceCollection(evidenceIds: selectedIds);
    if (mounted) {
      AppSnackBar.showSuccess(context, 'Evidence group created.');
    }
  }

  void _acceptSuggestion(String collectionId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.acceptEvidenceCollection(collectionId);
  }

  void _dismissSuggestion(String collectionId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.dismissPendingEvidenceCollection(collectionId);
  }

  void _restoreSuggestion(String collectionId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.restorePendingEvidenceCollection(collectionId);
  }

  void _removeFromGroup(String collectionId, String evidenceId) {
    if (!_sessionMatchesBound || _controller.isArchivedReadOnly) {
      return;
    }
    _controller.removeEvidenceFromCollection(
      collectionId: collectionId,
      evidenceId: evidenceId,
    );
  }

  Future<List<String>?> _pickEvidenceForNewGroup() async {
    final items = InvestigateIncidentScope.presentation(
      _controller.currentIncident,
      widget.boundIncidentId,
    ).journeyEvidence;
    if (items.length < 2) {
      return null;
    }

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create evidence group', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Select at least two records. Grouping does not merge evidence or change chronology.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final item in items)
                            CheckboxListTile(
                              value: selected.contains(item.id),
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    selected.add(item.id);
                                  } else {
                                    selected.remove(item.id);
                                  }
                                });
                              },
                              title: Text(item.title),
                              subtitle: Text(item.kind.label),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: selected.length < 2
                          ? null
                          : () => Navigator.pop(context, selected.toList()),
                      child: const Text('Create group'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final currentIncident = InvestigateIncidentScope.presentation(
          _controller.currentIncident,
          widget.boundIncidentId,
        );
        final enrichment = _controller.enrichment;
        final journeyEvidence = currentIncident.journeyEvidence;

        if (_connectModeActive && journeyEvidence.length < 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_connectModeActive) {
              return;
            }
            _cancelConnectMode();
          });
        }

        if (_isEvidenceStage) {
          return OrganizeWorkspaceView(
            incident: currentIncident,
            dismissedCollectionIds: _controller.dismissedCollectionIds,
            onEvidenceSelected: _handleJourneyEvidenceTap,
            onCreateGroup:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _createGroup
                : null,
            onAcceptSuggestion:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _acceptSuggestion
                : null,
            onDismissSuggestion:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _dismissSuggestion
                : null,
            onRestoreSuggestion:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _restoreSuggestion
                : null,
            contextAnchors: _controller.organizeContextAnchors,
            organizeCreatedIds: _controller.organizeCreatedEvidenceIds,
            onAddOrganizeContext:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _addOrganizeContext
                : null,
            onSetContextAnchor:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? (contextId, capturedId) {
                    _controller.setOrganizeContextAnchor(
                      contextEvidenceId: contextId,
                      capturedEvidenceId: capturedId,
                    );
                  }
                : null,
            onClearContextAnchor:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _controller.clearOrganizeContextAnchor
                : null,
            onDiscardUnsnappedContext:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? (id) {
                    _controller.discardUnsnappedOrganizeContext(id);
                  }
                : null,
            orderedCapturedEvidenceIds: _controller.timelineRepository
                .orderedCapturedEvidenceIds(),
            capturedAnchoredAtById: {
              for (final anchor in _controller.timelineRepository.anchors)
                if (anchor.capturedEvidenceId.isNotEmpty)
                  anchor.capturedEvidenceId: anchor.anchoredAt,
            },
            onRemoveFromGroup:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _removeFromGroup
                : null,
            onUpsertInterpretiveGroup:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? ({required category, required name, collectionId}) =>
                      _controller.upsertInterpretiveGroup(
                        category: category.name,
                        name: name,
                        collectionId: collectionId,
                      )
                : null,
            onSetInterpretiveGroupMembership:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? ({
                    required collectionId,
                    required evidenceId,
                    required associated,
                  }) {
                    _controller.setInterpretiveGroupMembership(
                      collectionId: collectionId,
                      evidenceId: evidenceId,
                      associated: associated,
                    );
                  }
                : null,
            onCreateCustomGroup:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? ({required name, evidenceIds = const <String>[]}) =>
                      _controller.createCustomGroup(
                        name: name,
                        evidenceIds: evidenceIds,
                      )
                : null,
            onCommitGroupComposition:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? ({required name, required evidenceIds, collectionId}) =>
                      _controller.commitCustomGroupComposition(
                        name: name,
                        evidenceIds: evidenceIds,
                        collectionId: collectionId,
                      )
                : null,
            onDeleteCustomGroup:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? _controller.deleteUserCustomGroup
                : null,
            onGroupCompositionChanged: widget.onGroupCompositionChanged,
            onRenameGroupPerson:
                _sessionMatchesBound && !_controller.isArchivedReadOnly
                ? (participantId, displayName) {
                    _controller.renameParticipantIdentity(
                      participantId: participantId,
                      displayName: displayName,
                    );
                  }
                : null,
          );
        }

        return PopScope(
          canPop: !_connectModeActive,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            _cancelConnectMode();
          },
          child: WorkspaceBody(
            evidence: currentIncident.evidence,
            relationshipGroups: currentIncident.relationshipGroups,
            reflections: _controller.sortedReflections,
            incidentId: currentIncident.id,
            incidentName: currentIncident.title,
            onIncidentNameChanged: _controller.isArchivedReadOnly
                ? null
                : _handleIncidentNameChanged,
            onJourneyEvidenceTap: _handleJourneyEvidenceTap,
            onConnectPressed: null,
            onCancelConnect: null,
            connectModeActive: false,
            connectSelectedEvidenceIds: const {},
            connectPendingColorIndex: 0,
            showConnectAction: false,
            onEnterInvestigation: widget.onEnterInvestigation,
            activeCaptureMode: _activeCaptureMode,
            onCaptureModeSelected: _handleCaptureModeSelected,
            onAddReflection: _openAddReflection,
            onEditReflection: _openEditReflection,
            animateEvidenceId: _animateEvidenceId,
            journeyEvidence: journeyEvidence,
            timelineAnchorCount: currentIncident.timelineAnchorCount,
            supportingEvidenceCount: _controller.supportingEvidenceCount,
            currentStage: currentIncident.journeyStage,
            currentCoaching: enrichment.coaching,
            presentation: widget.presentation,
            resolveParticipantName: (participantId) =>
                _controller.participantDisplayName(participantId),
            suggestedCollectionsPanel: null,
          ),
        );
      },
    );
  }
}
