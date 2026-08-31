import '../domain/reconstruction/narrative_event.dart';
import 'incident_store.dart';

/// Owns structured [NarrativeEvent] persistence for an incident.
abstract class NarrativeEventRepository {
  List<NarrativeEvent> get events;

  /// Creates one placeholder event per timeline anchor when none exist.
  void ensureInitialStructure({required List<String> orderedAnchorEvidenceIds});

  /// Refreshes traceability references without overwriting investigator edits.
  void refreshReferences({
    required List<String> orderedAnchorEvidenceIds,
    required Map<String, NarrativeEventReferences> referencesByEventId,
  });

  NarrativeEvent? updateTitle({required String eventId, required String title});

  NarrativeEvent? updateSummary({
    required String eventId,
    required String? summary,
  });

  void reorderEvents({required List<String> orderedEventIds});

  bool moveEventUp({required String eventId});

  bool moveEventDown({required String eventId});

  bool insertEventBefore({
    required String eventId,
    required String beforeEventId,
  });

  bool insertEventAfter({
    required String eventId,
    required String afterEventId,
  });
}

class NarrativeEventReferences {
  const NarrativeEventReferences({
    this.relationshipGroupIds = const [],
    this.reconstructionNoteIds = const [],
    this.supportingEvidenceIds = const [],
  });

  final List<String> relationshipGroupIds;
  final List<String> reconstructionNoteIds;
  final List<String> supportingEvidenceIds;
}

class InMemoryNarrativeEventRepository implements NarrativeEventRepository {
  InMemoryNarrativeEventRepository(this._store);

  final IncidentStore _store;
  static int _counter = 0;

  @override
  List<NarrativeEvent> get events =>
      List<NarrativeEvent>.unmodifiable(_store.narrativeEvents);

  @override
  void ensureInitialStructure({
    required List<String> orderedAnchorEvidenceIds,
  }) {
    if (_store.narrativeEvents.isEmpty) {
      for (var i = 0; i < orderedAnchorEvidenceIds.length; i++) {
        _store.narrativeEvents.add(
          NarrativeEvent(
            id: _nextId(),
            incidentId: _store.incident.id,
            sortOrder: i,
            title: '${NarrativeEvent.defaultTitlePrefix} ${i + 1}',
            timelineAnchorEvidenceId: orderedAnchorEvidenceIds[i],
          ),
        );
      }
      _touchIncident();
      return;
    }

    _syncMissingAnchors(orderedAnchorEvidenceIds);
  }

  @override
  void refreshReferences({
    required List<String> orderedAnchorEvidenceIds,
    required Map<String, NarrativeEventReferences> referencesByEventId,
  }) {
    _syncMissingAnchors(orderedAnchorEvidenceIds);

    for (var i = 0; i < _store.narrativeEvents.length; i++) {
      final event = _store.narrativeEvents[i];
      final refs = referencesByEventId[event.id];
      if (refs == null) {
        continue;
      }
      _store.narrativeEvents[i] = event.copyWith(
        relationshipGroupIds: List<String>.from(refs.relationshipGroupIds),
        reconstructionNoteIds: List<String>.from(refs.reconstructionNoteIds),
        supportingEvidenceIds: List<String>.from(refs.supportingEvidenceIds),
      );
    }
    _touchIncident();
  }

  @override
  NarrativeEvent? updateTitle({
    required String eventId,
    required String title,
  }) {
    final index = _indexOf(eventId);
    if (index == -1) {
      return null;
    }

    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final updated = _store.narrativeEvents[index].copyWith(
      title: trimmed,
      titleCustomized: true,
    );
    _store.narrativeEvents[index] = updated;
    _touchIncident();
    return updated;
  }

  @override
  NarrativeEvent? updateSummary({
    required String eventId,
    required String? summary,
  }) {
    final index = _indexOf(eventId);
    if (index == -1) {
      return null;
    }

    final trimmed = summary?.trim() ?? '';
    final updated = trimmed.isEmpty
        ? _store.narrativeEvents[index].copyWith(clearSummary: true)
        : _store.narrativeEvents[index].copyWith(
            summary: trimmed.length > NarrativeEvent.maxSummaryLength
                ? trimmed.substring(0, NarrativeEvent.maxSummaryLength)
                : trimmed,
            summaryCustomized: true,
          );
    _store.narrativeEvents[index] = updated;
    _touchIncident();
    return updated;
  }

  @override
  void reorderEvents({required List<String> orderedEventIds}) {
    if (orderedEventIds.isEmpty) {
      return;
    }

    final byId = {
      for (final event in _store.narrativeEvents) event.id: event,
    };

    final reordered = <NarrativeEvent>[];
    for (var i = 0; i < orderedEventIds.length; i++) {
      final event = byId[orderedEventIds[i]];
      if (event != null) {
        reordered.add(event.copyWith(sortOrder: i));
      }
    }

    for (final event in _store.narrativeEvents) {
      if (!orderedEventIds.contains(event.id)) {
        reordered.add(event.copyWith(sortOrder: reordered.length));
      }
    }

    _applyOrder(reordered);
  }

  @override
  bool moveEventUp({required String eventId}) {
    final ordered = _sortedEvents();
    final index = ordered.indexWhere((event) => event.id == eventId);
    if (index <= 0) {
      return false;
    }
    final moved = ordered.removeAt(index);
    ordered.insert(index - 1, moved);
    _applyOrder(ordered);
    return true;
  }

  @override
  bool moveEventDown({required String eventId}) {
    final ordered = _sortedEvents();
    final index = ordered.indexWhere((event) => event.id == eventId);
    if (index == -1 || index >= ordered.length - 1) {
      return false;
    }
    final moved = ordered.removeAt(index);
    ordered.insert(index + 1, moved);
    _applyOrder(ordered);
    return true;
  }

  @override
  bool insertEventBefore({
    required String eventId,
    required String beforeEventId,
  }) {
    if (eventId == beforeEventId) {
      return false;
    }

    final ordered = _sortedEvents();
    final event = _removeById(ordered, eventId);
    if (event == null) {
      return false;
    }

    final insertIndex = ordered.indexWhere((entry) => entry.id == beforeEventId);
    if (insertIndex == -1) {
      ordered.add(event);
    } else {
      ordered.insert(insertIndex, event);
    }
    _applyOrder(ordered);
    return true;
  }

  @override
  bool insertEventAfter({
    required String eventId,
    required String afterEventId,
  }) {
    if (eventId == afterEventId) {
      return false;
    }

    final ordered = _sortedEvents();
    final event = _removeById(ordered, eventId);
    if (event == null) {
      return false;
    }

    final insertIndex = ordered.indexWhere((entry) => entry.id == afterEventId);
    if (insertIndex == -1) {
      ordered.add(event);
    } else {
      ordered.insert(insertIndex + 1, event);
    }
    _applyOrder(ordered);
    return true;
  }

  List<NarrativeEvent> _sortedEvents() {
    return List<NarrativeEvent>.from(_store.narrativeEvents)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  NarrativeEvent? _removeById(List<NarrativeEvent> ordered, String eventId) {
    final index = ordered.indexWhere((event) => event.id == eventId);
    if (index == -1) {
      return null;
    }
    return ordered.removeAt(index);
  }

  void _applyOrder(List<NarrativeEvent> ordered) {
    _store.narrativeEvents
      ..clear()
      ..addAll([
        for (var i = 0; i < ordered.length; i++)
          ordered[i].copyWith(sortOrder: i),
      ]);
    _touchIncident();
  }

  void _syncMissingAnchors(List<String> orderedAnchorEvidenceIds) {
    final coveredAnchors = _store.narrativeEvents
        .map((event) => event.timelineAnchorEvidenceId)
        .toSet();

    var nextOrder = _store.narrativeEvents.isEmpty
        ? 0
        : _store.narrativeEvents
                .map((event) => event.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;

    var nextEventNumber = _store.narrativeEvents.length + 1;

    for (final anchorId in orderedAnchorEvidenceIds) {
      if (coveredAnchors.contains(anchorId)) {
        continue;
      }
      _store.narrativeEvents.add(
        NarrativeEvent(
          id: _nextId(),
          incidentId: _store.incident.id,
          sortOrder: nextOrder,
          title: '${NarrativeEvent.defaultTitlePrefix} $nextEventNumber',
          timelineAnchorEvidenceId: anchorId,
        ),
      );
      nextOrder += 1;
      nextEventNumber += 1;
    }
  }

  int _indexOf(String eventId) {
    return _store.narrativeEvents.indexWhere((event) => event.id == eventId);
  }

  void _touchIncident() {
    _store.incident = _store.incident.copyWith(updatedAt: DateTime.now());
  }

  static String _nextId() {
    _counter += 1;
    return 'narrative-event-$_counter';
  }

  static void resetForTests() {
    _counter = 0;
  }
}
