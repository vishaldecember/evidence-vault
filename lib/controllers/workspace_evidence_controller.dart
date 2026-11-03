import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../domain/collection/evidence_collection.dart';
import '../domain/evidence/evidence_integrity.dart';
import '../domain/evidence/evidence_provenance_event.dart';
import '../domain/evidence/evidence_sync_status.dart';
import '../domain/evidence/evidence_temporal_intent.dart';
import '../domain/incident/current_incident.dart';
import '../domain/incident/incident_status.dart';
import '../domain/participant/evidence_person_relationship.dart';
import '../domain/participant/participant.dart';
import '../domain/participant/related_person_link.dart';
import '../domain/participant/related_person_metadata.dart';
import '../domain/incident/incident_aggregate.dart';
import '../domain/incident/incident_composition.dart';
import '../domain/organize/organize_context_anchor.dart';
import '../domain/organize/organize_readiness.dart';
import '../domain/trust_package/trust_package.dart';
import '../domain/trust_package/trust_package_assembler.dart';
import '../engines/insight_engine.dart';
import '../engines/rule_based_insight_engine.dart';
import '../engines/narrative_builder.dart';
import '../engines/enrichment_engine.dart';
import '../mappers/current_incident_projection.dart';
import '../mappers/evidence_projection.dart';
import '../presentation/evidence_inspector_semantics.dart';
import '../models/journey_stage.dart';
import '../models/evidence_relationship.dart';
import '../models/insight_model.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/relationship_type.dart';
import '../models/story_model.dart';
import '../models/connection_group_node.dart';
import '../models/timeline_anchor_node.dart';
import '../models/timeline_item_model.dart';
import '../models/trust_package_model.dart';
import '../models/verification_factory.dart';
import '../models/workspace_capture_mode.dart';
import '../models/workspace_evidence_item.dart';
import '../repositories/evidence_repository.dart';
import '../repositories/incident_repository.dart';
import '../repositories/in_memory_evidence_repository.dart';
import '../repositories/narrative_event_repository.dart';
import '../repositories/participant_repository.dart';
import '../repositories/reconstruction_repository.dart';
import '../repositories/relationship_repository.dart';
import '../repositories/timeline_repository.dart';
import '../repositories/workspace_evidence_repository.dart';
import '../services/capture/capture_engine.dart';
import '../services/capture/capture_job.dart';
import '../services/capture/capture_provenance.dart';
import '../services/metadata_service.dart';
import '../services/collection/collection_engine.dart';
import '../services/organize/organize_context_anchor_store.dart';
import '../services/relationship/relationship_engine.dart';
import '../services/storage/capture_media_service.dart';
import '../services/storage/evidence_upload_coordinator.dart';
import '../services/storage/evidence_upload_models.dart';
import '../services/storage/local_evidence_cache.dart';
import '../services/storage/storage_upload_result.dart';
import '../services/sync/evidence_sync_manager.dart';
import '../services/persistence/incident_cloud_sync_service.dart';
import '../services/persistence/incident_library_service.dart';
import '../services/persistence/local_incident_pointer.dart';
import '../services/persistence/organize_context_persistence.dart';
import '../services/user_session_service.dart';
import '../services/workspace_coaching_service.dart';
import '../story/story_builder.dart';
import '../trust_package/trust_package_builder.dart';
import '../widgets/evidence/location_unavailable_dialog.dart';

/// Presentation-layer controller backed by the Sprint 9 [IncidentAggregate].
///
/// Owns the shared [CurrentIncident] projection. Screens subscribe via
/// [ListenableBuilder] — they never keep separate incident copies.
///
/// Projects legacy [WorkspaceEvidenceState] for UI compatibility while routing
/// mutations through domain repositories.
class WorkspaceEvidenceController extends ChangeNotifier
    implements CapturePipelineHost {
  WorkspaceEvidenceController({
    WorkspaceEvidenceState? initialState,
    IncidentAggregate? aggregate,
    InsightEngine? insightEngine,
    StoryBuilder? storyBuilder,
    TrustPackageBuilder? trustPackageBuilder,
    NarrativeBuilder? narrativeBuilder,
  }) : _aggregate =
           aggregate ??
           (initialState != null
               ? IncidentAggregate.fromLegacyState(initialState)
               : IncidentAggregate.empty()),
       _insightEngine = insightEngine ?? const RuleBasedInsightEngine(),
       _storyBuilder = storyBuilder ?? const DefaultStoryBuilder(),
       _trustPackageBuilder =
           trustPackageBuilder ?? const DefaultTrustPackageBuilder(),
       _narrativeBuilder = narrativeBuilder ?? const DefaultNarrativeBuilder() {
    _syncRichBaseline();
  }

  /// Mutable so [WorkspaceSession] can hydrate/clear without replacing this
  /// [ChangeNotifier] instance (widgets must keep listening to the same object).
  IncidentAggregate _aggregate;
  final InsightEngine _insightEngine;
  final StoryBuilder _storyBuilder;
  final TrustPackageBuilder _trustPackageBuilder;
  final NarrativeBuilder _narrativeBuilder;

  List<WorkspaceEvidenceItem>? _sortedItemsCache;
  List<ReflectionModel>? _sortedReflectionsCache;
  List<InsightModel>? _insightsCache;
  StoryModel? _storyCache;
  TrustPackageModel? _trustPackageCache;
  List<TimelineItemModel>? _timelineCache;
  final Map<String, List<WorkspaceEvidenceItem>> _linkableCache = {};
  int? _richBaselinePrimaryCount;
  EnrichmentSnapshot? _enrichmentCache;
  List<TimelineAnchorNode>? _anchoredTimelineCache;
  List<ConnectionGroupNode>? _connectionGroupNodesCache;
  List<NarrativeEventViewModel>? _narrativeEventsCache;
  CurrentIncident? _currentIncidentCache;
  bool _notifyPending = false;
  Timer? _persistDebounce;
  int _persistGeneration = 0;
  CaptureProvenanceSnapshot? lastCaptureProvenance;
  bool locationPromptDismissed = false;

  IncidentAggregate get aggregate => _aggregate;

  /// Replaces the backing aggregate in place — used for cloud restore / clear.
  ///
  /// Never dispose this controller while workspace widgets are listening.
  void replaceAggregate(IncidentAggregate aggregate) {
    if (identical(_aggregate, aggregate)) {
      return;
    }
    _persistGeneration++;
    _persistDebounce?.cancel();
    _aggregate = aggregate;
    _richBaselinePrimaryCount = null;
    _invalidateDerivedCaches(schedulePersist: false);
    _syncRichBaseline();
  }

  /// Clears to a fresh empty incident without disposing this notifier.
  void resetToEmpty() {
    replaceAggregate(IncidentAggregate.empty());
  }

  /// Shared incident projection — single source of truth for every screen.
  ///
  /// Owns the only evidence collection UI may read. After each capture,
  /// [notifyListeners] delivers the updated collection to all observers.
  CurrentIncident get currentIncident =>
      _currentIncidentCache ??= CurrentIncidentProjection.fromAggregate(
        _aggregate,
        enrichment: enrichment,
        narrativeEventCount: narrativeEventCount,
      );

  /// Archived incidents are viewable and inspectable, not editable.
  bool get isArchivedReadOnly {
    final id = currentIncident.id.trim();
    if (id.isEmpty) {
      return false;
    }
    if (currentIncident.status == IncidentStatus.archived ||
        currentIncident.status == IncidentStatus.recentlyDeleted) {
      return true;
    }
    final library = IncidentLibraryService.instance;
    return library.isArchivedId(id) || library.isRecentlyDeletedId(id);
  }

  IncidentRepository get incidentRepository => _aggregate.incidentRepository;

  EvidenceRepository get evidenceRepository => _aggregate.evidenceRepository;

  TimelineRepository get timelineRepository => _aggregate.timelineRepository;

  /// Derived Organize usefulness. Never persisted on the Incident.
  OrganizeReadiness get organizeReadiness => OrganizeReadiness.assess(
    evidence: currentIncident.evidence,
    orderedCapturedEvidenceIds: timelineRepository.orderedCapturedEvidenceIds(),
  );

  ReconstructionRepository get reconstructionRepository =>
      _aggregate.reconstructionRepository;

  NarrativeEventRepository get narrativeEventRepository =>
      _aggregate.narrativeEventRepository;

  RelationshipRepository get relationshipRepository =>
      _aggregate.relationshipRepository;

  ParticipantRepository get participantRepository =>
      _aggregate.participantRepository;

  WorkspaceEvidenceState get state => _aggregate.projectedState;

  EnrichmentSnapshot get enrichment =>
      _enrichmentCache ??= EnrichmentEngine.compute(
        EnrichmentContext(
          items: state.items,
          relationships: state.relationships,
          richBaselinePrimaryCount: _richBaselinePrimaryCount,
        ),
      );

  JourneyStage get journeyStage => enrichment.journeyStage;

  String get journeyCoachingMessage => enrichment.coachingMessage;

  WorkspaceCoaching get journeyCoaching => enrichment.coaching;

  /// Journey strip — alias of [CurrentIncident.journeyEvidence] (no second list).
  List<WorkspaceEvidenceItem> get journeyEvidenceItems =>
      currentIncident.journeyEvidence;

  /// Latest-first presentation order derived from [CurrentIncident.evidence].
  List<WorkspaceEvidenceItem> get sortedItems => _sortedItemsCache ??= () {
    final sorted = List<WorkspaceEvidenceItem>.from(currentIncident.evidence)
      ..sort((a, b) => b.lastPreservedAt.compareTo(a.lastPreservedAt));
    return List<WorkspaceEvidenceItem>.unmodifiable(sorted);
  }();

  List<ReflectionModel> get sortedReflections =>
      _sortedReflectionsCache ??= state.sortedReflections;

  List<InsightModel> get insights =>
      _insightsCache ??= _insightEngine.generateInsights(
        InsightContext(
          items: state.items,
          relationships: state.relationships,
          reflections: state.reflections,
        ),
      );

  StoryModel get story => _storyCache ??= _storyBuilder.build(
    StoryBuildContext(
      items: state.items,
      relationships: state.relationships,
      reflections: state.reflections,
    ),
  );

  TrustPackageModel get trustPackage =>
      _trustPackageCache ??= _trustPackageBuilder.build(
        TrustPackageBuildContext(
          items: state.items,
          relationships: state.relationships,
          reflections: state.reflections,
        ),
      );

  /// Canonical domain Trust Package projection for preview and export.
  TrustPackage get canonicalTrustPackage {
    return _canonicalTrustPackageCache ??= _assembleCanonicalTrustPackage();
  }

  TrustPackage? _canonicalTrustPackageCache;

  TrustPackage _assembleCanonicalTrustPackage() {
    _aggregate.narrativeEventRepository.ensureInitialStructure(
      orderedAnchorEvidenceIds: _aggregate.timelineRepository
          .orderedCapturedEvidenceIds(),
    );
    return DefaultTrustPackageAssembler().assemble(_aggregate);
  }

  List<TimelineItemModel> get timelineItems =>
      _timelineCache ??= TimelineItemModel.fromIncidentAggregate(_aggregate);

  /// Anchor-ordered tree for the Timeline Workspace.
  List<TimelineAnchorNode> get anchoredTimeline =>
      _anchoredTimelineCache ??= WorkspaceEvidenceRepository.anchoredTree(
        _aggregate.store,
        _aggregate.timelineRepository,
      );

  int get timelineAnchorCount =>
    _aggregate.timelineRepository.orderedCapturedEvidenceIds()
        .where((id) => _aggregate.store.capturedEvidence
            .any((evidence) => evidence.id == id))
        .length;

  int get supportingEvidenceCount =>
      _aggregate.evidenceRepository.supportingEvidence.length;

  int get relationshipGroupCount =>
      _aggregate.relationshipRepository.groups.length;

  /// Relationship group presentation for the Connections Workspace.
  List<ConnectionGroupNode> get connectionGroupNodes =>
      _connectionGroupNodesCache ??=
          WorkspaceEvidenceRepository.connectionGroupNodes(
            _aggregate.store,
            _aggregate.timelineRepository,
          );

  /// Structured narrative projection for the Narrative Builder.
  List<NarrativeEventViewModel> get narrativeEvents {
    _ensureNarrativeStructure();
    return _narrativeEventsCache ??= _buildNarrativeEvents();
  }

  int get narrativeEventCount => narrativeEvents.length;

  void _ensureNarrativeStructure() {
    final orderedAnchorIds = _aggregate.timelineRepository
        .orderedCapturedEvidenceIds();
    _aggregate.narrativeEventRepository.ensureInitialStructure(
      orderedAnchorEvidenceIds: orderedAnchorIds,
    );
  }

  List<NarrativeEventViewModel> _buildNarrativeEvents() {
    final context = NarrativeBuildContext(
      store: _aggregate.store,
      timelineNodes: anchoredTimeline,
      groupNodes: connectionGroupNodes,
      notes: sortedReflections,
      items: state.items,
      groups: state.relationshipGroups,
      enrichmentContext: EnrichmentContext(
        items: state.items,
        relationships: state.relationships,
      ),
    );

    final viewModels = _narrativeBuilder.build(context);
    _aggregate.narrativeEventRepository.refreshReferences(
      orderedAnchorEvidenceIds: _aggregate.timelineRepository
          .orderedCapturedEvidenceIds(),
      referencesByEventId: {
        for (final viewModel in viewModels)
          viewModel.event.id: NarrativeEventReferences(
            relationshipGroupIds: viewModel.relationshipGroups
                .map((group) => group.id)
                .toList(),
            reconstructionNoteIds: viewModel.reconstructionNotes
                .map((note) => note.id)
                .toList(),
            supportingEvidenceIds: viewModel.supportingEvidence
                .map((item) => item.id)
                .toList(),
          ),
      },
    );
    return viewModels;
  }

  void _invalidateDerivedCaches({bool schedulePersist = true}) {
    _sortedItemsCache = null;
    _sortedReflectionsCache = null;
    _insightsCache = null;
    _storyCache = null;
    _trustPackageCache = null;
    _timelineCache = null;
    _linkableCache.clear();
    _enrichmentCache = null;
    _anchoredTimelineCache = null;
    _connectionGroupNodesCache = null;
    _narrativeEventsCache = null;
    _canonicalTrustPackageCache = null;
    _currentIncidentCache = null;
    _scheduleNotify();
    // Local-first Library card count — do not wait for Firestore refresh.
    _publishLibraryEvidenceCount();
    if (schedulePersist) {
      _scheduleCloudPersist();
    }
  }

  /// Publishes this incident's evidence/context counts to Library by id.
  void _publishLibraryEvidenceCount() {
    publishLibraryComposition();
  }

  /// Library composition from the live aggregate. [allowZeroEvidence] is for
  /// post-hydrate truth; the default keeps last-known counts across an empty
  /// Library → open shell so the card does not flash Evidence: 0.
  void publishLibraryComposition({bool allowZeroEvidence = false}) {
    final incident = currentIncident;
    if (incident.id.isEmpty) {
      return;
    }
    final composition = IncidentComposition.fromStore(_aggregate.store);
    final isEmptyShell = composition.evidenceCount == 0 &&
        composition.contextEnrichedCount == 0 &&
        !allowZeroEvidence;
    IncidentLibraryService.instance.upsertFromLocal(
      incidentId: incident.id,
      title: incident.title,
      evidenceCount: composition.evidenceCount,
      contextEnrichedCount:
          isEmptyShell ? null : composition.contextEnrichedCount,
      journeyStage: isEmptyShell ? null : incident.journeyStage,
      updatedAt: incident.updatedAt,
      isInProgress: !incident.manuallyComplete,
      allowZeroEvidence: allowZeroEvidence,
    );
  }

  /// Debounced Firestore write-through — never blocks Capture / Workspace paint.
  void _scheduleCloudPersist() {
    _persistDebounce?.cancel();
    final generation = _persistGeneration;
    final aggregate = _aggregate;

    void run() {
      if (generation != _persistGeneration) {
        return;
      }
      unawaited(IncidentCloudSyncService.instance.persistAggregate(aggregate));
    }

    // Widget tests forbid pending Timers after dispose.
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      run();
      return;
    }

    _persistDebounce = Timer(const Duration(milliseconds: 450), run);
  }

  void _notifyNarrativeChanged() {
    _narrativeEventsCache = null;
    _canonicalTrustPackageCache = null;
    _currentIncidentCache = null;
    _scheduleNotify();
  }

  /// Batches listener updates so capture during mount never notifies mid-build.
  void _scheduleNotify() {
    if (_notifyPending) {
      return;
    }
    _notifyPending = true;
    scheduleMicrotask(() {
      _notifyPending = false;
      notifyListeners();
    });
  }

  void _syncRichBaseline() {
    final snapshot = enrichment;
    if (snapshot.primaryEvidenceCount == 0) {
      _richBaselinePrimaryCount = null;
      return;
    }
    if (snapshot.journeyStage == JourneyStage.rich) {
      _richBaselinePrimaryCount = snapshot.primaryEvidenceCount;
    }
  }

  void preserveEvidence(WorkspaceCaptureMode mode) {
    if (isArchivedReadOnly) {
      return;
    }
    _captureFromMode(mode);
    _invalidateDerivedCaches();
    _syncRichBaseline();
  }

  String preserveEvidenceAndReturnId(
    WorkspaceCaptureMode mode, {
    bool asOrganizeContext = false,
  }) {
    if (isArchivedReadOnly) {
      return '';
    }
    final id = _captureFromMode(mode, asOrganizeContext: asOrganizeContext);
    _recordCaptureLifecycle(evidenceId: id, mode: mode);
    _invalidateDerivedCaches();
    _syncRichBaseline();
    return id;
  }

  /// Captures evidence with optional local media and kicks off Firebase upload.
  ///
  /// Awaits **local commit** (RAM + LocalEvidenceCache) then returns.
  /// Thumbnail / Storage / Firestore continue in the background.
  Future<String> preserveEvidenceWithMedia({
    required WorkspaceCaptureMode mode,
    CapturedMediaFile? media,
    EvidenceUploadCoordinator? uploadCoordinator,
    String? noteText,
    String? mimeType,
    bool linkToNearestPrimary = false,
    bool asOrganizeContext = false,
  }) async {
    if (isArchivedReadOnly) {
      return '';
    }
    return CaptureEngine.instance
        .receive(
          host: this,
          mode: mode,
          media: media,
          uploadCoordinator: uploadCoordinator,
          noteText: noteText,
          mimeType: mimeType,
          createLocalEvidence: (captureSessionId) {
            final id = _captureFromMode(
              mode,
              noteText: noteText,
              fileName: media?.fileName,
              mimeType: mimeType,
              captureSessionId: captureSessionId,
              linkToNearestPrimary: linkToNearestPrimary,
              asOrganizeContext: asOrganizeContext,
            );
            _invalidateDerivedCaches();
            _syncRichBaseline();
            return id;
          },
        )
        .then((id) {
          unawaited(_offerLocationIfMissing(id));
          return id;
        });
  }

  /// In-memory preserve for FakeAsync widget tests (no CaptureSession store I/O).
  String preserveForWidgetTest(
    WorkspaceCaptureMode mode, {
    String? noteText,
    bool asOrganizeContext = false,
  }) {
    if (isArchivedReadOnly) {
      return '';
    }
    final id = _captureFromMode(
      mode,
      noteText: noteText,
      asOrganizeContext: asOrganizeContext,
    );
    final hash = (noteText != null && noteText.trim().isNotEmpty)
        ? EvidenceIntegrity.sha256OfUtf8(noteText.trim())
        : null;
    _recordCaptureLifecycle(evidenceId: id, mode: mode, contentHash: hash);
    _invalidateDerivedCaches();
    _syncRichBaseline();
    return id;
  }

  /// Capture-bar text note — dedicated evidence, no silent parent attach.
  Future<String> preserveTextNote(
    String text, {
    bool asOrganizeContext = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Text note must not be empty');
    }
    return preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.note,
      noteText: trimmed,
      linkToNearestPrimary: false,
      asOrganizeContext: asOrganizeContext,
    );
  }

  @override
  String get captureIncidentId => currentIncident.id;

  @override
  String get captureIncidentTitle => currentIncident.title;

  @override
  void rememberCaptureProvenance(CaptureProvenanceSnapshot snapshot) {
    lastCaptureProvenance = snapshot;
  }

  @override
  void applyCaptureProvenance({
    required String evidenceId,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {
    evidenceRepository.applyCaptureProvenance(
      evidenceId: evidenceId,
      deviceModel: deviceModel,
      latitude: latitude,
      longitude: longitude,
    );
    _invalidateDerivedCaches();
  }

  @override
  void recordContentHash({required String evidenceId, required String hash}) {
    if (evidenceRepository.recordContentHash(
      evidenceId: evidenceId,
      hash: hash,
    )) {
      debugPrint('[Integrity] Evidence $evidenceId SHA-256 generated');
      _invalidateDerivedCaches();
    }
  }

  @override
  void appendEvidenceProvenance(EvidenceProvenanceEvent event) {
    if (evidenceRepository.appendProvenanceEvent(event)) {
      _invalidateDerivedCaches();
    }
  }

  /// Recomputes SHA-256 of the preserved original and compares it.
  ///
  /// Does not overwrite a recorded hash on mismatch.
  Future<EvidenceIntegrityCheck> verifyEvidenceIntegrity(
    String evidenceId,
  ) async {
    final item = currentIncident.evidenceById(evidenceId);
    if (item == null) {
      return EvidenceIntegrityCheck.payloadUnavailable;
    }
    return EvidenceIntegrity.verifyOriginal(
      recordedHash: item.contentHash,
      originalFilePath: item.filePath,
      thumbnailPath: item.thumbnailPath,
      noteText: item.notePreview,
    );
  }

  void _recordCaptureLifecycle({
    required String evidenceId,
    required WorkspaceCaptureMode mode,
    String? contentHash,
    String? storageReference,
    DateTime? capturedAt,
    DateTime? preservedAt,
  }) {
    final modality = _modalityForMode(mode);
    final source = _deviceModelFor(evidenceId);
    final captured = capturedAt ?? DateTime.now().toUtc();
    appendEvidenceProvenance(
      EvidenceProvenanceEvent(
        type: EvidenceProvenanceType.captured,
        evidenceId: evidenceId,
        at: captured,
        captureModality: modality,
        source: source,
      ),
    );
    if (contentHash != null && contentHash.trim().isNotEmpty) {
      recordContentHash(evidenceId: evidenceId, hash: contentHash);
    }
    appendEvidenceProvenance(
      EvidenceProvenanceEvent(
        type: EvidenceProvenanceType.preserved,
        evidenceId: evidenceId,
        at: preservedAt ?? DateTime.now().toUtc(),
        captureModality: modality,
        source: source,
        contentHash: contentHash,
        storageReference: storageReference,
      ),
    );
  }

  String? _deviceModelFor(String evidenceId) {
    for (final item in _aggregate.store.capturedEvidence) {
      if (item.id == evidenceId) {
        return item.deviceModel?.trim();
      }
    }
    for (final item in _aggregate.store.supportingEvidence) {
      if (item.id == evidenceId) {
        return item.deviceModel?.trim();
      }
    }
    return null;
  }

  static String _modalityForMode(WorkspaceCaptureMode mode) {
    return EvidenceInspectorSemantics.captureModality(
      WorkspaceEvidenceItem(
        id: 'modality',
        kind: WorkspaceEvidenceKind.fromCaptureMode(mode),
        title: mode.label,
        lastPreservedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        integrityVerified: false,
        verification: VerificationFactory.initial(),
      ),
    );
  }

  Future<bool> retryCaptureLocation(String evidenceId) async {
    final previous = lastCaptureProvenance;
    if (previous == null) {
      return false;
    }
    final next = await MetadataService.retryLocation(previous);
    lastCaptureProvenance = next;
    if (!next.hasCoordinates) {
      return false;
    }
    applyCaptureProvenance(
      evidenceId: evidenceId,
      deviceModel: next.device.name.trim().isEmpty ? null : next.device.name,
      latitude: next.location.latitude,
      longitude: next.location.longitude,
    );
    return true;
  }

  Future<void> _offerLocationIfMissing(String evidenceId) async {
    if (evidenceId.isEmpty || locationPromptDismissed) {
      return;
    }
    final snapshot = lastCaptureProvenance;
    if (snapshot == null || !snapshot.shouldPromptForLocation) {
      return;
    }
    await CaptureLocationPrompt.offer(
      status: snapshot.locationStatus,
      onRetry: () => retryCaptureLocation(evidenceId),
      onDismissed: () => locationPromptDismissed = true,
    );
  }

  @override
  void attachCaptureThumbnail({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  }) {
    evidenceRepository.attachLocalMedia(
      evidenceId: evidenceId,
      filePath: filePath,
      fileName: fileName,
      thumbnailPath: thumbnailPath,
      fileSizeBytes: fileSizeBytes,
    );
    _invalidateDerivedCaches();
  }

  @override
  void scheduleCaptureMetadataPersist() {
    _invalidateDerivedCaches();
  }

  @override
  void abandonFailedLocalCapture(String evidenceId) {
    evidenceRepository.removeEvidence(evidenceId: evidenceId);
    _invalidateDerivedCaches();
    _syncRichBaseline();
  }

  @override
  void completeCaptureUpload({
    required String evidenceId,
    required String storagePath,
    required String downloadUrl,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {
    evidenceRepository.applyStorageUpload(
      evidenceId: evidenceId,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      thumbnailUrl: thumbnailUrl,
      deviceModel: deviceModel,
      latitude: latitude,
      longitude: longitude,
    );
    _invalidateDerivedCaches();
  }

  @override
  void failCaptureUpload(String evidenceId) {
    evidenceRepository.markUploadFailed(evidenceId: evidenceId);
    _invalidateDerivedCaches();
  }

  @override
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) {
    final ok = evidenceRepository.updateLifecycleStatus(
      evidenceId: evidenceId,
      status: status,
      uploadProgress: uploadProgress,
      retryCount: retryCount,
      force: force,
    );
    if (ok) {
      _invalidateDerivedCaches();
    }
    return ok;
  }

  Future<StorageUploadResult?> retryEvidenceUpload(
    String evidenceId, {
    EvidenceUploadCoordinator? uploadCoordinator,
  }) async {
    // Retry ownership is EvidenceSyncManager / EvidenceSyncQueue.
    // Coordinator remains the progress + Storage worker, not a second queue.
    await EvidenceSyncManager.instance.retry(evidenceId);
    return null;
  }

  EvidenceUploadProgress? uploadProgressFor(String evidenceId) =>
      EvidenceUploadCoordinator.instance.progressFor(evidenceId);

  /// Deletes evidence from local store, Firestore, Storage, and relationships.
  Future<void> deleteEvidence(String evidenceId) async {
    if (isArchivedReadOnly) {
      return;
    }
    await IncidentCloudSyncService.instance.deleteEvidenceCascade(
      incidentId: currentIncident.id,
      evidenceId: evidenceId,
      store: _aggregate.store,
    );
    _invalidateDerivedCaches();
    _persistOrganizeContextSoon();
  }

  String _captureFromMode(
    WorkspaceCaptureMode mode, {
    String? noteText,
    String? fileName,
    String? mimeType,
    String? captureSessionId,
    bool linkToNearestPrimary = false,
    bool asOrganizeContext = false,
  }) {
    if (EvidenceProjection.isCapturedCaptureMode(mode)) {
      return _aggregate.evidenceRepository
          .addCapturedFromCaptureMode(mode, captureSessionId: captureSessionId)
          .id;
    }

    // Capture-bar notes/files are standalone chronological evidence.
    final parentEvidenceId = linkToNearestPrimary
        ? _nearestPrimaryEvidenceId()
        : null;
    final supporting =
        (_aggregate.evidenceRepository as InMemoryEvidenceRepository)
            .addStandaloneSupportingFromCaptureMode(
              mode,
              parentEvidenceId: parentEvidenceId,
              noteText: noteText,
              fileName: fileName,
              mimeType: mimeType,
              captureSessionId: captureSessionId,
              createTimelineAnchor: !asOrganizeContext,
            );
    return supporting.id;
  }

  /// Most recently captured Photo / Video / Voice — parent for new supporting.
  String? _nearestPrimaryEvidenceId() {
    final ordered = _aggregate.timelineRepository.orderedCapturedEvidenceIds();
    if (ordered.isEmpty) {
      return null;
    }
    return ordered.last;
  }

  void addContextEvidence({
    required String parentEvidenceId,
    required WorkspaceCaptureMode mode,
  }) {
    if (isArchivedReadOnly) {
      return;
    }
    _aggregate.evidenceRepository.addSupportingFromCaptureMode(
      mode,
      parentCapturedEvidenceId: parentEvidenceId,
    );
    _invalidateDerivedCaches();
    _syncRichBaseline();
  }

  /// Returns the created supporting-note id, or null when [text] is empty.
  String? addContextTextNote({
    required String parentEvidenceId,
    required String text,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final supporting = _aggregate.evidenceRepository.addSupportingTextNote(
      parentCapturedEvidenceId: parentEvidenceId,
      text: trimmed,
    );
    _recordCaptureLifecycle(
      evidenceId: supporting.id,
      mode: WorkspaceCaptureMode.note,
      contentHash: EvidenceIntegrity.sha256OfUtf8(trimmed),
    );
    _invalidateDerivedCaches();
    _syncRichBaseline();
    return supporting.id;
  }

  /// Persists edits to a text-note evidence body from the Evidence Inspector.
  void updateEvidenceNoteText({
    required String evidenceId,
    required String text,
  }) {
    final updated = _aggregate.evidenceRepository.updateSupportingNoteText(
      evidenceId: evidenceId,
      text: text,
    );
    if (updated == null) {
      return;
    }
    _invalidateDerivedCaches();
  }

  /// Persists timeline role only. Does not reorder or rewrite chronology.
  bool setTemporalIntent({
    required String evidenceId,
    required EvidenceTemporalIntent intent,
  }) {
    if (isArchivedReadOnly) {
      return false;
    }
    final updated = _aggregate.evidenceRepository.updateTemporalIntent(
      evidenceId: evidenceId,
      intent: intent,
    );
    if (!updated) {
      return false;
    }
    _invalidateDerivedCaches();
    return true;
  }

  RelationshipGroup? commitRelationshipGroup({
    required List<String> evidenceIds,
    RelationshipType type = RelationshipType.relatedTo,
  }) {
    final group = _aggregate.relationshipRepository.commitRelationshipGroup(
      evidenceIds: evidenceIds,
      type: type,
    );
    if (group != null) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return group;
  }

  /// Generates / refreshes Organize-stage Evidence Collections (Sprint 5B).
  List<EvidenceCollection> ensureEvidenceCollections() {
    final collections = CollectionEngine.instance.ensureCollections(
      store: _aggregate.store,
    );
    _invalidateDerivedCaches();
    return collections;
  }

  List<EvidenceCollection> get evidenceCollections =>
      List.unmodifiable(_aggregate.store.evidenceCollections);

  void renameEvidenceCollection({
    required String collectionId,
    required String name,
  }) {
    if (isArchivedReadOnly) {
      return;
    }
    CollectionEngine.instance.renameCollection(
      store: _aggregate.store,
      collectionId: collectionId,
      name: name,
    );
    _invalidateDerivedCaches();
  }

  EvidenceCollection? mergeEvidenceCollections({
    required String primaryId,
    required String secondaryId,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final merged = CollectionEngine.instance.mergeCollections(
      store: _aggregate.store,
      primaryId: primaryId,
      secondaryId: secondaryId,
    );
    if (merged != null) {
      _invalidateDerivedCaches();
    }
    return merged;
  }

  EvidenceCollection? splitEvidenceCollection({
    required String collectionId,
    required List<String> moveEvidenceIds,
    String? newName,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final created = CollectionEngine.instance.splitCollection(
      store: _aggregate.store,
      collectionId: collectionId,
      moveEvidenceIds: moveEvidenceIds,
      newName: newName,
    );
    if (created != null) {
      _invalidateDerivedCaches();
    }
    return created;
  }

  void moveEvidenceToCollection({
    required String evidenceId,
    required String toCollectionId,
  }) {
    if (isArchivedReadOnly) {
      return;
    }
    CollectionEngine.instance.moveEvidence(
      store: _aggregate.store,
      evidenceId: evidenceId,
      toCollectionId: toCollectionId,
    );
    _invalidateDerivedCaches();
  }

  /// Removes membership only. Evidence remains in the Incident.
  bool removeEvidenceFromCollection({
    required String collectionId,
    required String evidenceId,
  }) {
    if (isArchivedReadOnly) {
      return false;
    }
    final removed = CollectionEngine.instance.removeEvidenceFromCollection(
      store: _aggregate.store,
      collectionId: collectionId,
      evidenceId: evidenceId,
    );
    if (removed) {
      _invalidateDerivedCaches();
    }
    return removed;
  }

  bool deleteEmptyEvidenceCollection(String collectionId) {
    if (isArchivedReadOnly) {
      return false;
    }
    final removed = CollectionEngine.instance.deleteEmptyCollection(
      store: _aggregate.store,
      collectionId: collectionId,
    );
    if (removed) {
      _invalidateDerivedCaches();
    }
    return removed;
  }

  EvidenceCollection? acceptEvidenceCollection(String collectionId) {
    if (isArchivedReadOnly) {
      return null;
    }
    final accepted = CollectionEngine.instance.acceptSuggestion(
      store: _aggregate.store,
      collectionId: collectionId,
    );
    if (accepted != null) {
      _invalidateDerivedCaches();
    }
    return accepted;
  }

  EvidenceCollection? createUserEvidenceCollection({
    required List<String> evidenceIds,
    String? name,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final created = CollectionEngine.instance.createUserCollection(
      store: _aggregate.store,
      evidenceIds: evidenceIds,
      name: name,
    );
    if (created != null) {
      _invalidateDerivedCaches();
    }
    return created;
  }

  bool deleteUserCustomGroup(String collectionId) {
    if (isArchivedReadOnly) {
      return false;
    }
    final removed = CollectionEngine.instance.deleteUserCustomGroup(
      store: _aggregate.store,
      collectionId: collectionId,
    );
    if (removed) {
      _invalidateDerivedCaches();
    }
    return removed;
  }

  EvidenceCollection? commitCustomGroupComposition({
    required String name,
    required List<String> evidenceIds,
    String? collectionId,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final committed = CollectionEngine.instance.commitCustomGroupComposition(
      store: _aggregate.store,
      name: name,
      evidenceIds: evidenceIds,
      collectionId: collectionId,
    );
    if (committed != null) {
      _invalidateDerivedCaches();
    }
    return committed;
  }

  EvidenceCollection? createCustomGroup({
    required String name,
    List<String> evidenceIds = const [],
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final created = CollectionEngine.instance.createCustomGroup(
      store: _aggregate.store,
      name: name,
      evidenceIds: evidenceIds,
    );
    if (created != null) {
      _invalidateDerivedCaches();
    }
    return created;
  }

  EvidenceCollection? upsertInterpretiveGroup({
    required String category,
    required String name,
    String? collectionId,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final created = CollectionEngine.instance.upsertInterpretiveGroup(
      store: _aggregate.store,
      category: category,
      name: name,
      collectionId: collectionId,
    );
    if (created != null) {
      _invalidateDerivedCaches();
    }
    return created;
  }

  bool setInterpretiveGroupMembership({
    required String collectionId,
    required String evidenceId,
    required bool associated,
  }) {
    if (isArchivedReadOnly) {
      return false;
    }
    final changed = CollectionEngine.instance.setInterpretiveMembership(
      store: _aggregate.store,
      collectionId: collectionId,
      evidenceId: evidenceId,
      associated: associated,
    );
    if (changed) {
      _invalidateDerivedCaches();
    }
    return changed;
  }

  void dismissPendingEvidenceCollection(String collectionId) {
    if (isArchivedReadOnly) {
      return;
    }
    CollectionEngine.instance.dismissPendingCollection(
      store: _aggregate.store,
      collectionId: collectionId,
    );
    _invalidateDerivedCaches();
  }

  /// Reopens a dismissed Organize suggestion for review. Still pending.
  void restorePendingEvidenceCollection(String collectionId) {
    if (isArchivedReadOnly) {
      return;
    }
    CollectionEngine.instance.restorePendingCollection(
      store: _aggregate.store,
      collectionId: collectionId,
    );
    _invalidateDerivedCaches();
  }

  Set<String> get dismissedCollectionIds =>
      Set.unmodifiable(_aggregate.store.dismissedCollectionIds);

  List<OrganizeContextAnchor> get organizeContextAnchors =>
      List.unmodifiable(_aggregate.store.organizeContextAnchors);

  Set<String> get organizeCreatedEvidenceIds =>
      Set.unmodifiable(_aggregate.store.organizeCreatedEvidenceIds);

  /// Marks evidence as Organize-toolbar floating context.
  /// Never adds it to capture chronology or the fixed spine.
  void registerOrganizeCreatedEvidence(String evidenceId) {
    final id = evidenceId.trim();
    if (id.isEmpty) {
      return;
    }
    final exists =
        _aggregate.store.capturedEvidence.any((e) => e.id == id) ||
        _aggregate.store.supportingEvidence.any((e) => e.id == id);
    if (!exists) {
      return;
    }
    _aggregate.store.organizeCreatedEvidenceIds.add(id);
    unawaited(_markCacheOrganizeContext(id));
    _invalidateDerivedCaches();
    _persistOrganizeContextSoon();
  }

  Future<void> _markCacheOrganizeContext(String evidenceId) async {
    try {
      final entry = await LocalEvidenceCache.byId(evidenceId);
      if (entry == null) {
        return;
      }
      await LocalEvidenceCache.upsert(
        entry.copyWith(
          metadata: {
            ...entry.metadata,
            'organizeContext': 'true',
          },
        ),
      );
    } catch (error) {
      debugPrint('[Organize] cache context stamp skipped: $error');
    }
  }

  /// Voice / Note / File from the Organize toolbar — not Capture chronology.
  String addOrganizeContextEvidence(WorkspaceCaptureMode mode) {
    if (isArchivedReadOnly) {
      return '';
    }
    if (mode != WorkspaceCaptureMode.voice &&
        mode != WorkspaceCaptureMode.note &&
        mode != WorkspaceCaptureMode.file) {
      throw ArgumentError.value(
        mode,
        'mode',
        'Organize context is Voice, Note, or File only',
      );
    }
    final id = preserveEvidenceAndReturnId(
      mode,
      asOrganizeContext: true,
    );
    registerOrganizeCreatedEvidence(id);
    return id;
  }

  OrganizeContextAnchor? setOrganizeContextAnchor({
    required String contextEvidenceId,
    required String capturedEvidenceId,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final anchor = OrganizeContextAnchorStore.instance.setAnchor(
      store: _aggregate.store,
      contextEvidenceId: contextEvidenceId,
      capturedEvidenceId: capturedEvidenceId,
    );
    if (anchor != null) {
      appendEvidenceProvenance(
        EvidenceProvenanceEvent(
          type: EvidenceProvenanceType.contextAdded,
          evidenceId: contextEvidenceId,
          at: DateTime.now().toUtc(),
          storageReference: capturedEvidenceId,
        ),
      );
      _invalidateDerivedCaches();
      _persistOrganizeContextSoon();
    }
    return anchor;
  }

  void clearOrganizeContextAnchor(String contextEvidenceId) {
    OrganizeContextAnchorStore.instance.clearAnchor(
      store: _aggregate.store,
      contextEvidenceId: contextEvidenceId,
    );
    _invalidateDerivedCaches();
    _persistOrganizeContextSoon();
  }

  /// Removes one Organize-created context. Never deletes captured chronology
  /// evidence or other context items. Clears a snap link first if present.
  ///
  /// Local store + Organize persistence update immediately so the floating
  /// context cannot survive a rebuild or a return to Organize. Cloud cleanup
  /// is fire-and-forget on the existing cascade path.
  Future<void> discardUnsnappedOrganizeContext(String evidenceId) async {
    final id = evidenceId.trim();
    if (id.isEmpty || isArchivedReadOnly) {
      return;
    }
    if (!_aggregate.store.organizeCreatedEvidenceIds.contains(id)) {
      return;
    }

    OrganizeContextAnchorStore.instance.clearAnchor(
      store: _aggregate.store,
      contextEvidenceId: id,
    );
    _aggregate.store.organizeCreatedEvidenceIds.remove(id);
    _aggregate.evidenceRepository.removeEvidence(evidenceId: id);

    _invalidateDerivedCaches();
    await persistOrganizeContextPersistence();
    await LocalEvidenceCache.remove(id);
    unawaited(
      IncidentCloudSyncService.instance.deleteEvidenceCascade(
        incidentId: currentIncident.id,
        evidenceId: id,
        store: _aggregate.store,
      ),
    );
  }

  void _persistOrganizeContextSoon() {
    unawaited(persistOrganizeContextPersistence());
  }

  /// Writes Organize origin + explicit snap links for this incident.
  Future<void> persistOrganizeContextPersistence() async {
    final incidentId = _aggregate.store.incident.id;
    if (incidentId.trim().isEmpty) {
      return;
    }
    await OrganizeContextPersistence.save(
      incidentId: incidentId,
      createdIds: _aggregate.store.organizeCreatedEvidenceIds,
      anchors: _aggregate.store.organizeContextAnchors,
    );
  }

  /// Restores Organize origin + explicit snaps after hydrate/restart.
  /// Does not create evidence, chronology, or inferred links.
  Future<void> restoreOrganizeContextPersistence() async {
    final changed = await OrganizeContextPersistence.applyTo(_aggregate.store);
    if (changed) {
      _invalidateDerivedCaches(schedulePersist: false);
    }
  }

  /// Async-safe relationship enrichment for Investigation (Sprint 5C).
  void ensureInvestigationRelationships() {
    unawaited(
      Future<void>(() async {
        RelationshipEngine.instance.ensureRelationships(
          store: _aggregate.store,
          relationshipRepository: relationshipRepository,
        );
        _invalidateDerivedCaches();
      }),
    );
  }

  InvestigationGraphView get investigationGraph {
    return RelationshipEngine.instance.buildGraphView(
      store: _aggregate.store,
      evidence: currentIncident.evidence,
      relationships: relationshipRepository.all,
    );
  }

  void setPrimaryEvidence({
    required String evidenceId,
    required bool isPrimary,
  }) {
    final index = _aggregate.store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (index < 0) {
      return;
    }
    final current = _aggregate.store.capturedEvidence[index];
    if (current.isPrimaryEvidence == isPrimary) {
      return;
    }
    _aggregate.store.capturedEvidence[index] = current.copyWith(
      isPrimaryEvidence: isPrimary,
    );
    _invalidateDerivedCaches();
  }

  RelationshipGroup? moveSupportingToGroup({
    required String supportingEvidenceId,
    required String targetGroupId,
  }) {
    final group = _aggregate.relationshipRepository.moveSupportingToGroup(
      supportingEvidenceId: supportingEvidenceId,
      targetGroupId: targetGroupId,
    );
    if (group != null) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return group;
  }

  RelationshipGroup? removeSupportingFromGroup({
    required String supportingEvidenceId,
    required String groupId,
  }) {
    final group = _aggregate.relationshipRepository.removeSupportingFromGroup(
      supportingEvidenceId: supportingEvidenceId,
      groupId: groupId,
    );
    if (group != null) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return group;
  }

  RelationshipGroup? mergeRelationshipGroups({
    required String sourceGroupId,
    required String targetGroupId,
  }) {
    final group = _aggregate.relationshipRepository.mergeGroups(
      sourceGroupId: sourceGroupId,
      targetGroupId: targetGroupId,
    );
    if (group != null) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return group;
  }

  RelationshipGroup? splitRelationshipGroup({
    required String groupId,
    required List<String> supportingEvidenceIds,
  }) {
    final group = _aggregate.relationshipRepository.splitGroup(
      groupId: groupId,
      supportingEvidenceIds: supportingEvidenceIds,
    );
    if (group != null) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return group;
  }

  bool deleteEmptyRelationshipGroup({required String groupId}) {
    final deleted = _aggregate.relationshipRepository.deleteEmptyGroup(
      groupId: groupId,
    );
    if (deleted) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return deleted;
  }

  RelationshipGroup? updateRelationshipGroupInvestigation({
    required String groupId,
    required String displayName,
    required String description,
  }) {
    final group = _aggregate.relationshipRepository.updateGroupInvestigation(
      groupId: groupId,
      displayName: displayName,
      description: description,
    );
    if (group != null) {
      _invalidateDerivedCaches();
    }
    return group;
  }

  EvidenceRelationship? linkExistingEvidence({
    required String sourceEvidenceId,
    required String targetEvidenceId,
    required RelationshipType type,
  }) {
    final relationship = _aggregate.relationshipRepository.linkEvidence(
      sourceEvidenceId: sourceEvidenceId,
      targetEvidenceId: targetEvidenceId,
      type: type,
    );
    if (relationship != null) {
      _invalidateDerivedCaches();
      _syncRichBaseline();
    }
    return relationship;
  }

  List<WorkspaceEvidenceItem> linkableArtifactsFor(String evidenceId) {
    return _linkableCache.putIfAbsent(evidenceId, () {
      return state.items
          .where(
            (item) =>
                item.id != evidenceId &&
                !_aggregate.relationshipRepository.isLinked(
                  sourceEvidenceId: evidenceId,
                  targetEvidenceId: item.id,
                ),
          )
          .toList()
        ..sort((a, b) => b.lastPreservedAt.compareTo(a.lastPreservedAt));
    });
  }

  ReflectionModel addReflection({String? title, required String body}) {
    final note = _aggregate.reconstructionRepository.add(
      title: title,
      body: body,
    );
    _invalidateDerivedCaches();
    return note;
  }

  ReflectionModel? updateReflection({
    required String reflectionId,
    String? title,
    required String body,
  }) {
    final updated = _aggregate.reconstructionRepository.update(
      noteId: reflectionId,
      title: title,
      body: body,
    );
    if (updated == null) {
      return null;
    }
    _invalidateDerivedCaches();
    return updated;
  }

  void updateIncidentName(String name) {
    if (isArchivedReadOnly) {
      return;
    }
    // Bind rename to the incident that is active at call time — never let a
    // stale TextEditingController write "Street Fight" onto a later id.
    final targetIncidentId = _aggregate.store.incident.id;
    if (targetIncidentId.isEmpty) {
      return;
    }
    _aggregate.incidentRepository.updateTitle(name);
    // Keep aggregate debounce for counters/evidence — title is durable below.
    _invalidateDerivedCaches();
    final userId = UserSessionService.account?.userId ?? '';
    final trimmed = name.trim();
    final generation = _persistGeneration;
    final incidentSnapshot = _aggregate.store.incident;
    if (userId.isNotEmpty) {
      if (trimmed.isEmpty) {
        // Explicit user clear — only this incidentId.
        unawaited(
          LocalIncidentPointer.clearTitleForIncident(
            userId: userId,
            incidentId: targetIncidentId,
          ),
        );
      } else {
        // Immediate per-incident local title (not user-scoped, not debounced).
        unawaited(
          LocalIncidentPointer.rememberTitle(
            userId: userId,
            incidentId: targetIncidentId,
            title: trimmed,
          ),
        );
      }
    }
    // Immediate identity write so restart does not reload Untitled.
    // Drop if Clear Vault / resetToEmpty advanced generation or switched id.
    unawaited(() async {
      if (generation != _persistGeneration) {
        return;
      }
      if (_aggregate.store.incident.id != targetIncidentId) {
        return;
      }
      await IncidentCloudSyncService.instance.persistIncidentOnly(
        incidentSnapshot,
      );
    }());
    IncidentLibraryService.instance.patchTitle(targetIncidentId, name);
  }

  void declareIncidentComplete() {
    _aggregate.incidentRepository.markManuallyComplete();
    _invalidateDerivedCaches();
  }

  void updateNarrativeEventTitle({
    required String eventId,
    required String title,
  }) {
    final updated = _aggregate.narrativeEventRepository.updateTitle(
      eventId: eventId,
      title: title,
    );
    if (updated != null) {
      _notifyNarrativeChanged();
    }
  }

  void updateNarrativeEventSummary({
    required String eventId,
    required String? summary,
  }) {
    final updated = _aggregate.narrativeEventRepository.updateSummary(
      eventId: eventId,
      summary: summary,
    );
    if (updated != null) {
      _notifyNarrativeChanged();
    }
  }

  void reorderNarrativeEvents({required List<String> orderedEventIds}) {
    _aggregate.narrativeEventRepository.reorderEvents(
      orderedEventIds: orderedEventIds,
    );
    _notifyNarrativeChanged();
  }

  void moveNarrativeEventUp({required String eventId}) {
    if (_aggregate.narrativeEventRepository.moveEventUp(eventId: eventId)) {
      _notifyNarrativeChanged();
    }
  }

  void moveNarrativeEventDown({required String eventId}) {
    if (_aggregate.narrativeEventRepository.moveEventDown(eventId: eventId)) {
      _notifyNarrativeChanged();
    }
  }

  void insertNarrativeEventBefore({
    required String eventId,
    required String beforeEventId,
  }) {
    if (_aggregate.narrativeEventRepository.insertEventBefore(
      eventId: eventId,
      beforeEventId: beforeEventId,
    )) {
      _notifyNarrativeChanged();
    }
  }

  void insertNarrativeEventAfter({
    required String eventId,
    required String afterEventId,
  }) {
    if (_aggregate.narrativeEventRepository.insertEventAfter(
      eventId: eventId,
      afterEventId: afterEventId,
    )) {
      _notifyNarrativeChanged();
    }
  }

  /// Rebuilds narrative projection from the latest incident aggregate state.
  void refreshNarrativeProjection() {
    _notifyNarrativeChanged();
  }

  String? participantDisplayName(String? participantId) {
    if (participantId == null) {
      return null;
    }
    return participantRepository.getById(participantId)?.displayName;
  }

  Participant? participantForEvidence(WorkspaceEvidenceItem evidence) {
    final people = relatedPeopleForEvidence(evidence);
    if (people.isEmpty) {
      return null;
    }
    return participantRepository.getById(people.first.participantId) ??
        participantRepository.getById(evidence.participantId ?? '');
  }

  List<RelatedPersonLink> relatedPeopleForEvidence(
    WorkspaceEvidenceItem evidence,
  ) {
    if (evidence.relatedPeople.isNotEmpty) {
      return evidence.relatedPeople;
    }
    final captured = evidenceRepository.capturedById(evidence.id);
    if (captured != null) {
      return RelatedPersonMetadata.peopleOf(captured.metadata);
    }
    final supporting = evidenceRepository.supportingById(evidence.id);
    if (supporting != null) {
      return RelatedPersonMetadata.peopleOf(supporting.metadata);
    }
    final name = evidence.relatedPersonName?.trim();
    if (name == null || name.isEmpty) {
      return const [];
    }
    return [
      RelatedPersonLink(
        participantId: evidence.participantId ?? '',
        displayName: name,
        roleName: evidence.relatedPersonRole,
      ),
    ];
  }

  List<Participant> recognizedParticipants() =>
      participantRepository.getByIncident();

  Participant assignRelatedPersonToEvidence({
    required String evidenceId,
    required String displayName,
    required EvidencePersonRelationship relationship,
    String? existingParticipantId,
  }) {
    return _resolveAndWritePerson(
      evidenceId: evidenceId,
      displayName: displayName,
      relationship: relationship,
      existingParticipantId: existingParticipantId,
      write: _assignParticipantToEvidence,
    );
  }

  Participant addRelatedPersonToEvidence({
    required String evidenceId,
    required String displayName,
    required EvidencePersonRelationship relationship,
    String? existingParticipantId,
  }) {
    return _resolveAndWritePerson(
      evidenceId: evidenceId,
      displayName: displayName,
      relationship: relationship,
      existingParticipantId: existingParticipantId,
      reuseByName: false,
      write:
          ({
            required String evidenceId,
            String? participantId,
            String? relatedPersonName,
            String? relatedPersonRole,
          }) {
            if (participantId == null || relatedPersonName == null) {
              return;
            }
            _addParticipantToEvidence(
              evidenceId: evidenceId,
              participantId: participantId,
              relatedPersonName: relatedPersonName,
              relatedPersonRole: relatedPersonRole,
            );
          },
    );
  }

  Participant replaceRelatedPersonOnEvidence({
    required String evidenceId,
    required String previousParticipantId,
    required String displayName,
    required EvidencePersonRelationship relationship,
    String? existingParticipantId,
  }) {
    return _resolveAndWritePerson(
      evidenceId: evidenceId,
      displayName: displayName,
      relationship: relationship,
      existingParticipantId: existingParticipantId,
      reuseByName: false,
      write:
          ({
            required String evidenceId,
            String? participantId,
            String? relatedPersonName,
            String? relatedPersonRole,
          }) {
            if (participantId == null || relatedPersonName == null) {
              return;
            }
            _replaceParticipantOnEvidence(
              evidenceId: evidenceId,
              previousParticipantId: previousParticipantId,
              participantId: participantId,
              relatedPersonName: relatedPersonName,
              relatedPersonRole: relatedPersonRole,
            );
          },
    );
  }

  void removeRelatedPersonFromEvidence({
    required String evidenceId,
    required String participantId,
  }) {
    final store = _aggregate.store;
    final isCaptured = store.capturedEvidence.any(
      (item) => item.id == evidenceId,
    );
    if (isCaptured) {
      evidenceRepository.removeParticipantFromCaptured(
        evidenceId: evidenceId,
        participantId: participantId,
      );
    } else {
      evidenceRepository.removeParticipantFromSupporting(
        evidenceId: evidenceId,
        participantId: participantId,
      );
    }
    _syncRelatedPersonNames(participantId);
    _invalidateDerivedCaches();
    unawaited(_persistEvidencePeopleCache(evidenceId));
  }

  Participant? renameParticipantIdentity({
    required String participantId,
    required String displayName,
  }) {
    if (isArchivedReadOnly) {
      return null;
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final updated = participantRepository.update(
      participantId: participantId,
      displayName: trimmed,
    );
    if (updated == null) {
      return null;
    }
    _syncRelatedPersonNames(participantId);
    _invalidateDerivedCaches();
    return updated;
  }

  void _assignParticipantToEvidence({
    required String evidenceId,
    String? participantId,
    String? relatedPersonName,
    String? relatedPersonRole,
  }) {
    final store = _aggregate.store;
    final isCaptured = store.capturedEvidence.any(
      (item) => item.id == evidenceId,
    );
    if (isCaptured) {
      evidenceRepository.assignParticipantToCaptured(
        evidenceId: evidenceId,
        participantId: participantId,
        relatedPersonName: relatedPersonName,
        relatedPersonRole: relatedPersonRole,
      );
      return;
    }

    evidenceRepository.assignParticipantToSupporting(
      evidenceId: evidenceId,
      participantId: participantId,
      relatedPersonName: relatedPersonName,
      relatedPersonRole: relatedPersonRole,
    );
  }

  Participant _resolveAndWritePerson({
    required String evidenceId,
    required String displayName,
    required EvidencePersonRelationship relationship,
    String? existingParticipantId,
    required void Function({
      required String evidenceId,
      String? participantId,
      String? relatedPersonName,
      String? relatedPersonRole,
    })
    write,
    bool reuseByName = true,
  }) {
    final trimmed = displayName.trim();
    Participant? participant;
    final existingId = existingParticipantId?.trim() ?? '';
    if (existingId.isNotEmpty) {
      participant = participantRepository.getById(existingId);
    }
    participant ??= reuseByName
        ? participantRepository.findOrCreateByDisplayName(
            displayName: trimmed,
            role: relationship.participantRole,
          )
        : participantRepository.create(
            displayName: trimmed,
            role: relationship.participantRole,
          );

    write(
      evidenceId: evidenceId,
      participantId: participant.id,
      relatedPersonName: participant.displayName,
      relatedPersonRole: relationship.name,
    );
    _invalidateDerivedCaches();
    unawaited(_persistEvidencePeopleCache(evidenceId));
    return participant;
  }

  void _addParticipantToEvidence({
    required String evidenceId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  }) {
    final store = _aggregate.store;
    final isCaptured = store.capturedEvidence.any(
      (item) => item.id == evidenceId,
    );
    if (isCaptured) {
      evidenceRepository.addParticipantToCaptured(
        evidenceId: evidenceId,
        participantId: participantId,
        relatedPersonName: relatedPersonName,
        relatedPersonRole: relatedPersonRole,
      );
      return;
    }
    evidenceRepository.addParticipantToSupporting(
      evidenceId: evidenceId,
      participantId: participantId,
      relatedPersonName: relatedPersonName,
      relatedPersonRole: relatedPersonRole,
    );
  }

  void _replaceParticipantOnEvidence({
    required String evidenceId,
    required String previousParticipantId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  }) {
    final store = _aggregate.store;
    final isCaptured = store.capturedEvidence.any(
      (item) => item.id == evidenceId,
    );
    if (isCaptured) {
      evidenceRepository.replaceParticipantOnCaptured(
        evidenceId: evidenceId,
        previousParticipantId: previousParticipantId,
        participantId: participantId,
        relatedPersonName: relatedPersonName,
        relatedPersonRole: relatedPersonRole,
      );
      return;
    }
    evidenceRepository.replaceParticipantOnSupporting(
      evidenceId: evidenceId,
      previousParticipantId: previousParticipantId,
      participantId: participantId,
      relatedPersonName: relatedPersonName,
      relatedPersonRole: relatedPersonRole,
    );
  }

  void _syncRelatedPersonNames(String participantId) {
    final participant = participantRepository.getById(participantId);
    if (participant == null) {
      return;
    }
    for (final evidence in _aggregate.store.capturedEvidence) {
      final people = RelatedPersonMetadata.peopleOf(evidence.metadata);
      if (people.every((person) => person.participantId != participantId)) {
        continue;
      }
      evidenceRepository.writeRelatedPeopleOnCaptured(
        evidenceId: evidence.id,
        people: [
          for (final person in people)
            person.participantId == participantId
                ? person.copyWith(displayName: participant.displayName)
                : person,
        ],
      );
      unawaited(_persistEvidencePeopleCache(evidence.id));
    }
    for (final evidence in _aggregate.store.supportingEvidence) {
      final people = RelatedPersonMetadata.peopleOf(evidence.metadata);
      if (people.every((person) => person.participantId != participantId)) {
        continue;
      }
      evidenceRepository.writeRelatedPeopleOnSupporting(
        evidenceId: evidence.id,
        people: [
          for (final person in people)
            person.participantId == participantId
                ? person.copyWith(displayName: participant.displayName)
                : person,
        ],
      );
      unawaited(_persistEvidencePeopleCache(evidence.id));
    }
  }

  Future<void> _persistEvidencePeopleCache(String evidenceId) async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      final entry = await LocalEvidenceCache.byId(evidenceId);
      if (entry == null) {
        return;
      }
      final captured = evidenceRepository.capturedById(evidenceId);
      final supporting = evidenceRepository.supportingById(evidenceId);
      final metadata = captured?.metadata ?? supporting?.metadata;
      if (metadata == null) {
        return;
      }
      await LocalEvidenceCache.upsert(entry.copyWith(metadata: metadata));
    } catch (_) {}
  }
}



