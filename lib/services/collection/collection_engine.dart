import 'package:flutter/foundation.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../models/workspace_evidence_item.dart';
import '../../repositories/incident_store.dart';
import 'collection_suggestion_provider.dart';
import 'heuristic_collection_provider.dart';

/// Sprint 5B — suggests and maintains Evidence Collections.
///
/// Capture Engine is untouched. Future AI providers implement
/// [CollectionSuggestionProvider] and are injected via [provider].
class CollectionEngine {
  CollectionEngine({CollectionSuggestionProvider? provider})
    : _provider = provider ?? HeuristicCollectionProvider();

  static final CollectionEngine instance = CollectionEngine();

  CollectionSuggestionProvider _provider;

  /// Swap heuristic provider for a future AI implementation.
  void useProvider(CollectionSuggestionProvider provider) {
    _provider = provider;
  }

  /// Ensures every evidence item is assigned. Regenerates system collections
  /// when empty or when unassigned evidence appears — preserves user renames
  /// and manually refined membership when [preserveUserRefinements] is true.
  List<EvidenceCollection> ensureCollections({
    required IncidentStore store,
    bool preserveUserRefinements = true,
  }) {
    final signals = _signalsFromStore(store);
    if (signals.isEmpty) {
      store.evidenceCollections.clear();
      return const [];
    }

    final existing = List<EvidenceCollection>.from(store.evidenceCollections);
    final assigned = <String>{for (final c in existing) ...c.memberEvidenceIds};
    final allIds = {for (final s in signals) s.evidenceId};
    final hasUnassigned = allIds.any((id) => !assigned.contains(id));
    final hasStale = assigned.any((id) => !allIds.contains(id));

    final userRefined =
        preserveUserRefinements &&
        existing.any((c) => !c.systemGenerated || _looksUserRenamed(c));

    if (existing.isEmpty || ((hasUnassigned || hasStale) && !userRefined)) {
      final suggested = _provider.suggest(
        incidentId: store.incident.id,
        signals: signals,
      );
      _applyCollections(store, suggested);
      return List.unmodifiable(store.evidenceCollections);
    }

    if (hasUnassigned) {
      _absorbUnassigned(store, signals, allIds.difference(assigned));
    }
    if (hasStale) {
      _pruneMissing(store, allIds);
    }
    _syncEvidenceCollectionIds(store);
    return List.unmodifiable(store.evidenceCollections);
  }

  void renameCollection({
    required IncidentStore store,
    required String collectionId,
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final index = store.evidenceCollections.indexWhere(
      (c) => c.id == collectionId,
    );
    if (index < 0) {
      return;
    }
    final current = store.evidenceCollections[index];
    store.evidenceCollections[index] = current.copyWith(
      name: trimmed,
      systemGenerated: false,
      pending: false,
      updatedAt: DateTime.now(),
    );
  }

  EvidenceCollection? mergeCollections({
    required IncidentStore store,
    required String primaryId,
    required String secondaryId,
  }) {
    if (primaryId == secondaryId) {
      return null;
    }
    final primaryIndex = store.evidenceCollections.indexWhere(
      (c) => c.id == primaryId,
    );
    final secondaryIndex = store.evidenceCollections.indexWhere(
      (c) => c.id == secondaryId,
    );
    if (primaryIndex < 0 || secondaryIndex < 0) {
      return null;
    }
    final primary = store.evidenceCollections[primaryIndex];
    final secondary = store.evidenceCollections[secondaryIndex];
    final merged = primary.copyWith(
      memberEvidenceIds: <String>{
        ...primary.memberEvidenceIds,
        ...secondary.memberEvidenceIds,
      }.toList(),
      systemGenerated: false,
      pending: false,
      updatedAt: DateTime.now(),
    );
    store.evidenceCollections
      ..removeWhere((c) => c.id == primaryId || c.id == secondaryId)
      ..add(merged);
    _reindex(store);
    _syncEvidenceCollectionIds(store);
    return merged;
  }

  EvidenceCollection? splitCollection({
    required IncidentStore store,
    required String collectionId,
    required List<String> moveEvidenceIds,
    String? newName,
  }) {
    final index = store.evidenceCollections.indexWhere(
      (c) => c.id == collectionId,
    );
    if (index < 0 || moveEvidenceIds.isEmpty) {
      return null;
    }
    final source = store.evidenceCollections[index];
    final moveSet = moveEvidenceIds.toSet();
    final remaining = [
      for (final id in source.memberEvidenceIds)
        if (!moveSet.contains(id)) id,
    ];
    final moved = [
      for (final id in source.memberEvidenceIds)
        if (moveSet.contains(id)) id,
    ];
    if (moved.isEmpty || remaining.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    store.evidenceCollections[index] = source.copyWith(
      memberEvidenceIds: remaining,
      systemGenerated: false,
      pending: false,
      updatedAt: now,
    );
    final created = EvidenceCollection(
      id: 'col_${store.incident.id}_split_${now.microsecondsSinceEpoch}',
      incidentId: store.incident.id,
      name: newName?.trim().isNotEmpty == true
          ? newName!.trim()
          : '${source.name} (split)',
      systemGenerated: false,
      pending: false,
      displayOrder: store.evidenceCollections.length,
      createdAt: now,
      updatedAt: now,
      memberEvidenceIds: moved,
    );
    store.evidenceCollections.add(created);
    _reindex(store);
    _syncEvidenceCollectionIds(store);
    return created;
  }

  void moveEvidence({
    required IncidentStore store,
    required String evidenceId,
    required String toCollectionId,
  }) {
    final targetIndex = store.evidenceCollections.indexWhere(
      (c) => c.id == toCollectionId,
    );
    if (targetIndex < 0) {
      return;
    }
    for (var i = 0; i < store.evidenceCollections.length; i++) {
      final collection = store.evidenceCollections[i];
      if (!collection.memberEvidenceIds.contains(evidenceId)) {
        continue;
      }
      store.evidenceCollections[i] = collection.copyWith(
        memberEvidenceIds: [
          for (final id in collection.memberEvidenceIds)
            if (id != evidenceId) id,
        ],
        systemGenerated: false,
        pending: false,
        updatedAt: DateTime.now(),
      );
    }
    final target = store.evidenceCollections[targetIndex];
    if (!target.memberEvidenceIds.contains(evidenceId)) {
      store.evidenceCollections[targetIndex] = target.copyWith(
        memberEvidenceIds: [...target.memberEvidenceIds, evidenceId],
        systemGenerated: false,
        pending: false,
        updatedAt: DateTime.now(),
      );
    }
    _syncEvidenceCollectionIds(store);
  }

  /// Removes [evidenceId] from one collection. Membership only — never deletes
  /// evidence, chronology, relationships, or anchors.
  bool removeEvidenceFromCollection({
    required IncidentStore store,
    required String collectionId,
    required String evidenceId,
  }) {
    final id = evidenceId.trim();
    if (id.isEmpty) {
      return false;
    }
    final index = store.evidenceCollections.indexWhere(
      (c) => c.id == collectionId,
    );
    if (index < 0) {
      return false;
    }
    final collection = store.evidenceCollections[index];
    if (!collection.memberEvidenceIds.contains(id)) {
      return false;
    }
    store.evidenceCollections[index] = collection.copyWith(
      memberEvidenceIds: [
        for (final memberId in collection.memberEvidenceIds)
          if (memberId != id) memberId,
      ],
      updatedAt: DateTime.now(),
    );
    _syncEvidenceCollectionIds(store);
    return true;
  }

  bool deleteEmptyCollection({
    required IncidentStore store,
    required String collectionId,
  }) {
    final index = store.evidenceCollections.indexWhere(
      (c) => c.id == collectionId,
    );
    if (index < 0) {
      return false;
    }
    if (store.evidenceCollections[index].memberEvidenceIds.isNotEmpty) {
      return false;
    }
    store.evidenceCollections.removeAt(index);
    _reindex(store);
    return true;
  }

  /// Removes a user-created custom group. Never deletes evidence records.
  ///
  /// System-generated groups are left untouched.
  bool deleteUserCustomGroup({
    required IncidentStore store,
    required String collectionId,
  }) {
    final id = collectionId.trim();
    if (id.isEmpty) {
      return false;
    }
    final index = store.evidenceCollections.indexWhere((c) => c.id == id);
    if (index < 0) {
      return false;
    }
    final current = store.evidenceCollections[index];
    if (current.systemGenerated) {
      return false;
    }
    store.evidenceCollections.removeAt(index);
    _reindex(store);
    _syncEvidenceCollectionIds(store);
    return true;
  }

  /// Confirms a pending engine suggestion in place — same id and members.
  EvidenceCollection? acceptSuggestion({
    required IncidentStore store,
    required String collectionId,
  }) {
    final index = store.evidenceCollections.indexWhere(
      (c) => c.id == collectionId,
    );
    if (index < 0) {
      return null;
    }
    final current = store.evidenceCollections[index];
    final accepted = current.copyWith(
      pending: false,
      systemGenerated: false,
      updatedAt: DateTime.now(),
    );
    store.evidenceCollections[index] = accepted;
    store.dismissedCollectionIds.remove(collectionId);
    _syncEvidenceCollectionIds(store);
    return accepted;
  }

  /// Investigator-created Organize collection — never a [RelationshipGroup].
  EvidenceCollection? createUserCollection({
    required IncidentStore store,
    required List<String> evidenceIds,
    String? name,
  }) {
    final ids = <String>{
      for (final id in evidenceIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    if (ids.length < 2) {
      return null;
    }
    final now = DateTime.now();
    final confirmedCount = store.evidenceCollections
        .where((c) => !c.pending)
        .length;
    for (var i = 0; i < store.evidenceCollections.length; i++) {
      final collection = store.evidenceCollections[i];
      final remaining = [
        for (final id in collection.memberEvidenceIds)
          if (!ids.contains(id)) id,
      ];
      if (remaining.length == collection.memberEvidenceIds.length) {
        continue;
      }
      store.evidenceCollections[i] = collection.copyWith(
        memberEvidenceIds: remaining,
        updatedAt: now,
      );
    }
    final created = EvidenceCollection(
      id: 'col_${store.incident.id}_user_${now.microsecondsSinceEpoch}',
      incidentId: store.incident.id,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'Group ${confirmedCount + 1}',
      systemGenerated: false,
      pending: false,
      displayOrder: store.evidenceCollections.length,
      createdAt: now,
      updatedAt: now,
      memberEvidenceIds: ids,
    );
    store.evidenceCollections.add(created);
    _reindex(store);
    _syncEvidenceCollectionIds(store);
    return created;
  }

  /// Manual custom group from Groups +. Overlay only — not a system lens.
  EvidenceCollection? createCustomGroup({
    required IncidentStore store,
    required String name,
    List<String> evidenceIds = const [],
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return null;
    }
    final ids = <String>[
      for (final id in evidenceIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    if (ids.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final created = EvidenceCollection(
      id: 'col_${store.incident.id}_custom_${now.microsecondsSinceEpoch}',
      incidentId: store.incident.id,
      name: trimmedName,
      category: 'custom',
      systemGenerated: false,
      pending: false,
      displayOrder: store.evidenceCollections.length,
      createdAt: now,
      updatedAt: now,
      memberEvidenceIds: ids,
    );
    store.evidenceCollections.add(created);
    _reindex(store);
    return created;
  }

  /// Persist a custom group composition. Membership is evidence IDs only.
  ///
  /// Requires at least one moment. An empty custom group is deleted, never kept.
  /// Does not copy or delete evidence records.
  EvidenceCollection? commitCustomGroupComposition({
    required IncidentStore store,
    required String name,
    required List<String> evidenceIds,
    String? collectionId,
  }) {
    final trimmedName = name.trim();
    final ids = <String>[
      for (final id in evidenceIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final unique = <String>[];
    for (final id in ids) {
      if (!unique.contains(id)) {
        unique.add(id);
      }
    }
    if (unique.isEmpty) {
      final existingId = (collectionId ?? '').trim();
      if (existingId.isEmpty) {
        return null;
      }
      deleteUserCustomGroup(store: store, collectionId: existingId);
      return null;
    }
    if (trimmedName.isEmpty && (collectionId ?? '').trim().isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final existingId = (collectionId ?? '').trim();
    if (existingId.isNotEmpty) {
      final index = store.evidenceCollections.indexWhere(
        (collection) => collection.id == existingId,
      );
      if (index >= 0) {
        final current = store.evidenceCollections[index];
        if (current.systemGenerated) {
          return null;
        }
        store.evidenceCollections[index] = current.copyWith(
          name: trimmedName.isEmpty ? current.name : trimmedName,
          category: current.category ?? 'custom',
          systemGenerated: false,
          pending: false,
          memberEvidenceIds: unique,
          updatedAt: now,
        );
        _reindex(store);
        return store.evidenceCollections[index];
      }
    }
    return createCustomGroup(
      store: store,
      name: trimmedName,
      evidenceIds: unique,
    );
  }

  /// Named interpretive Organize group (Person / Location / …).
  ///
  /// Membership is a relationship overlay — it does not steal evidence from
  /// heuristic collections or require two members up front.
  EvidenceCollection? upsertInterpretiveGroup({
    required IncidentStore store,
    required String category,
    required String name,
    String? collectionId,
  }) {
    final trimmedName = name.trim();
    final trimmedCategory = category.trim();
    if (trimmedName.isEmpty || trimmedCategory.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final byId = (collectionId ?? '').trim();
    final index = store.evidenceCollections.indexWhere((collection) {
      if (byId.isNotEmpty) {
        return collection.id == byId;
      }
      return collection.category == trimmedCategory &&
          collection.name.toLowerCase() == trimmedName.toLowerCase() &&
          !collection.pending;
    });
    if (index >= 0) {
      final current = store.evidenceCollections[index];
      if (current.name != trimmedName || current.category != trimmedCategory) {
        store.evidenceCollections[index] = current.copyWith(
          name: trimmedName,
          category: trimmedCategory,
          systemGenerated: false,
          pending: false,
          updatedAt: now,
        );
      }
      return store.evidenceCollections[index];
    }
    final created = EvidenceCollection(
      id: 'col_${store.incident.id}_group_${now.microsecondsSinceEpoch}',
      incidentId: store.incident.id,
      name: trimmedName,
      category: trimmedCategory,
      systemGenerated: false,
      pending: false,
      displayOrder: store.evidenceCollections.length,
      createdAt: now,
      updatedAt: now,
      memberEvidenceIds: const [],
    );
    store.evidenceCollections.add(created);
    _reindex(store);
    return created;
  }

  /// Adds or removes [evidenceId] on one interpretive group. Membership only.
  bool setInterpretiveMembership({
    required IncidentStore store,
    required String collectionId,
    required String evidenceId,
    required bool associated,
  }) {
    final id = evidenceId.trim();
    if (id.isEmpty || collectionId.trim().isEmpty) {
      return false;
    }
    final index = store.evidenceCollections.indexWhere(
      (c) => c.id == collectionId,
    );
    if (index < 0) {
      return false;
    }
    final collection = store.evidenceCollections[index];
    if ((collection.category ?? '').trim().isEmpty) {
      return false;
    }
    final members = [...collection.memberEvidenceIds];
    final contains = members.contains(id);
    if (associated && contains) {
      return false;
    }
    if (!associated && !contains) {
      return false;
    }
    if (associated) {
      members.add(id);
    } else {
      members.remove(id);
    }
    store.evidenceCollections[index] = collection.copyWith(
      memberEvidenceIds: members,
      systemGenerated: false,
      pending: false,
      updatedAt: DateTime.now(),
    );
    return true;
  }

  /// Hides a pending suggestion without deleting the [EvidenceCollection].
  void dismissPendingCollection({
    required IncidentStore store,
    required String collectionId,
  }) {
    if (collectionId.isEmpty) {
      return;
    }
    store.dismissedCollectionIds.add(collectionId);
  }

  /// Returns a dismissed suggestion to review — still pending, not accepted.
  void restorePendingCollection({
    required IncidentStore store,
    required String collectionId,
  }) {
    store.dismissedCollectionIds.remove(collectionId);
  }

  bool isPendingDismissed({
    required IncidentStore store,
    required String collectionId,
  }) {
    return store.dismissedCollectionIds.contains(collectionId);
  }

  void _applyCollections(
    IncidentStore store,
    List<EvidenceCollection> collections,
  ) {
    final keptDismissed = [
      for (final collection in store.evidenceCollections)
        if (store.dismissedCollectionIds.contains(collection.id)) collection,
    ];
    final incoming = [
      for (final collection in collections)
        if (!store.dismissedCollectionIds.contains(collection.id))
          _asEngineSuggestion(collection),
    ];
    store.evidenceCollections
      ..clear()
      ..addAll(keptDismissed)
      ..addAll(incoming);
    _syncEvidenceCollectionIds(store);
  }

  void _absorbUnassigned(
    IncidentStore store,
    List<CollectionEvidenceSignal> signals,
    Set<String> unassigned,
  ) {
    final fresh = _provider.suggest(
      incidentId: store.incident.id,
      signals: [
        for (final s in signals)
          if (unassigned.contains(s.evidenceId)) s,
      ],
    );
    final now = DateTime.now();
    for (final suggestion in fresh) {
      // Merge into existing same-name system collection when possible.
      final matchIndex = store.evidenceCollections.indexWhere(
        (c) => c.systemGenerated && c.name == suggestion.name,
      );
      if (store.dismissedCollectionIds.contains(suggestion.id)) {
        continue;
      }
      if (matchIndex >= 0) {
        final match = store.evidenceCollections[matchIndex];
        store.evidenceCollections[matchIndex] = match.copyWith(
          memberEvidenceIds: {
            ...match.memberEvidenceIds,
            ...suggestion.memberEvidenceIds,
          }.toList(),
          updatedAt: now,
        );
      } else {
        store.evidenceCollections.add(
          _asEngineSuggestion(
            suggestion.copyWith(
              displayOrder: store.evidenceCollections.length,
              updatedAt: now,
            ),
          ),
        );
      }
    }
    _reindex(store);
    _syncEvidenceCollectionIds(store);
  }

  void _pruneMissing(IncidentStore store, Set<String> validIds) {
    for (var i = 0; i < store.evidenceCollections.length; i++) {
      final c = store.evidenceCollections[i];
      final kept = [
        for (final id in c.memberEvidenceIds)
          if (validIds.contains(id)) id,
      ];
      if (kept.length != c.memberEvidenceIds.length) {
        store.evidenceCollections[i] = c.copyWith(
          memberEvidenceIds: kept,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  void _reindex(IncidentStore store) {
    for (var i = 0; i < store.evidenceCollections.length; i++) {
      final c = store.evidenceCollections[i];
      if (c.displayOrder != i) {
        store.evidenceCollections[i] = c.copyWith(displayOrder: i);
      }
    }
  }

  void _syncEvidenceCollectionIds(IncidentStore store) {
    final byEvidence = <String, String>{};
    for (final collection in store.evidenceCollections) {
      if (collection.category != null &&
          collection.category!.trim().isNotEmpty) {
        continue;
      }
      for (final id in collection.memberEvidenceIds) {
        byEvidence[id] = collection.id;
      }
    }

    for (var i = 0; i < store.capturedEvidence.length; i++) {
      final item = store.capturedEvidence[i];
      final nextId = byEvidence[item.id];
      if (item.collectionId != nextId) {
        store.capturedEvidence[i] = item.copyWith(
          collectionId: nextId,
          clearCollectionId: nextId == null,
        );
      }
    }
    for (var i = 0; i < store.supportingEvidence.length; i++) {
      final item = store.supportingEvidence[i];
      final nextId = byEvidence[item.id];
      if (item.collectionId != nextId) {
        store.supportingEvidence[i] = item.copyWith(
          collectionId: nextId,
          clearCollectionId: nextId == null,
        );
      }
    }
  }

  static EvidenceCollection _asEngineSuggestion(EvidenceCollection collection) {
    if (!collection.systemGenerated) {
      return collection.copyWith(pending: false);
    }
    return collection.pending ? collection : collection.copyWith(pending: true);
  }

  static bool _looksUserRenamed(EvidenceCollection collection) {
    const defaults = {'Media', 'Documents', 'Voice Notes', 'Notes', 'Other'};
    if (!collection.systemGenerated) {
      return true;
    }
    // Numbered session splits still count as system.
    final base = collection.name.replaceAll(RegExp(r'\s+\d+$'), '');
    return !defaults.contains(base) && !collection.name.contains('(split)');
  }

  static List<CollectionEvidenceSignal> _signalsFromStore(IncidentStore store) {
    final signals = <CollectionEvidenceSignal>[
      for (final item in store.capturedEvidence)
        CollectionEvidenceSignal(
          evidenceId: item.id,
          kindLabel: item.type.name,
          capturedAt: item.capturedAt,
          mimeType: item.mimeType,
          latitude: item.latitude,
          longitude: item.longitude,
          deviceModel: item.deviceModel,
          fileName: item.fileName,
        ),
      for (final item in store.supportingEvidence)
        CollectionEvidenceSignal(
          evidenceId: item.id,
          kindLabel: item.type.name,
          capturedAt: item.createdAt,
          mimeType: item.mimeType,
          latitude: item.latitude,
          longitude: item.longitude,
          deviceModel: item.deviceModel,
          fileName: item.fileName,
        ),
    ];
    return signals;
  }

  /// Preview helpers for UI cards.
  static List<WorkspaceEvidenceItem> membersOf({
    required EvidenceCollection collection,
    required List<WorkspaceEvidenceItem> evidence,
  }) {
    final byId = {for (final e in evidence) e.id: e};
    return [
      for (final id in collection.memberEvidenceIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @visibleForTesting
  void debugApplyForTests(
    IncidentStore store,
    List<EvidenceCollection> collections,
  ) {
    _applyCollections(store, collections);
  }
}
