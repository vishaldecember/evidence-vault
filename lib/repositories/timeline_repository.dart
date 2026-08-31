import '../domain/timeline/timeline_anchor.dart';
import 'incident_store.dart';

/// Owns immutable [TimelineAnchor] ordering for an incident.
abstract class TimelineRepository {
  List<TimelineAnchor> get anchors;

  TimelineAnchor createAnchor({
    required String capturedEvidenceId,
    required DateTime anchoredAt,
  });

  /// Chronological capture order — never sorted by UI timestamps.
  List<String> orderedCapturedEvidenceIds();
}

class InMemoryTimelineRepository implements TimelineRepository {
  InMemoryTimelineRepository(this._store);

  final IncidentStore _store;
  static int _anchorCounter = 0;

  @override
  List<TimelineAnchor> get anchors =>
      List<TimelineAnchor>.unmodifiable(_store.timelineAnchors);

  @override
  TimelineAnchor createAnchor({
    required String capturedEvidenceId,
    required DateTime anchoredAt,
  }) {
    final anchor = TimelineAnchor(
      id: _nextAnchorId(),
      incidentId: _store.incident.id,
      capturedEvidenceId: capturedEvidenceId,
      anchoredAt: anchoredAt,
      sequenceOrder: _store.timelineAnchors.length,
    );
    _store.timelineAnchors.add(anchor);
    return anchor;
  }

  @override
  List<String> orderedCapturedEvidenceIds() {
    final ordered = List<TimelineAnchor>.from(_store.timelineAnchors)
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return ordered.map((anchor) => anchor.capturedEvidenceId).toList();
  }

  static String _nextAnchorId() {
    _anchorCounter += 1;
    return 'timeline-anchor-$_anchorCounter';
  }

  static void resetForTests() {
    _anchorCounter = 0;
  }
}
