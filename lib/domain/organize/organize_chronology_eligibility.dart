import '../../models/workspace_evidence_item.dart';
import '../evidence/evidence_temporal_intent.dart';
import 'organize_spine_classification.dart';

/// Organize presentation chronology class — not a persisted evidence type.
///
/// Distinct from [EvidenceTemporalIntent] and from canonical
/// [TimelineAnchor.sequenceOrder].
enum OrganizeChronologyEligibility {
  /// On the chronological spine and present in canonical capture order.
  canonical,

  /// [EvidenceTemporalIntent.chronological] without canonical sequence.
  uncanonicalChronological,

  /// Null intent, capture-origin leftover. Existing O-2 / O-14 fallback.
  legacyFixed,

  /// Authored context — not chronology-eligible.
  context,
}

/// Organize presentation eligibility and ordering.
///
/// Does not write TimelineAnchors, sequenceOrder, timelineOrder, or timestamps.
abstract final class OrganizeChronologyEligibilityPolicy {
  static OrganizeChronologyEligibility classify({
    required WorkspaceEvidenceItem item,
    required List<String> orderedCapturedEvidenceIds,
    Set<String> organizeCreatedIds = const {},
  }) {
    // Toolbar-created context is never chronology-eligible — origin wins
    // even when a TimelineAnchor or chronological intent exists.
    if (OrganizeSpineClassification.isContextSpine(
      item: item,
      organizeCreatedIds: organizeCreatedIds,
    )) {
      return OrganizeChronologyEligibility.context;
    }
    if (orderedCapturedEvidenceIds.contains(item.id)) {
      return OrganizeChronologyEligibility.canonical;
    }
    if (item.temporalIntent == EvidenceTemporalIntent.chronological) {
      return OrganizeChronologyEligibility.uncanonicalChronological;
    }
    return OrganizeChronologyEligibility.legacyFixed;
  }

  static bool isChronologyEligible({
    required WorkspaceEvidenceItem item,
    required List<String> orderedCapturedEvidenceIds,
    Set<String> organizeCreatedIds = const {},
  }) {
    return classify(
          item: item,
          orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
          organizeCreatedIds: organizeCreatedIds,
        ) !=
        OrganizeChronologyEligibility.context;
  }

  /// Deterministic leftover clock. Not event time.
  static DateTime fallbackInstant(WorkspaceEvidenceItem item) {
    return item.capturedAt ?? item.recordedAt ?? item.lastPreservedAt;
  }

  static int fallbackCompare(
    WorkspaceEvidenceItem a,
    WorkspaceEvidenceItem b,
  ) {
    final byTime = fallbackInstant(a).compareTo(fallbackInstant(b));
    if (byTime != 0) {
      return byTime;
    }
    return a.id.compareTo(b.id);
  }

  /// Organize presentation order. Never mutates canonical chronology.
  ///
  /// 1. Canonical sequenceOrder items.
  /// 2. Explicitly chronological items without canonical sequence.
  /// 3. Legacy fixed-spine leftovers.
  /// 4. Authored context.
  static List<WorkspaceEvidenceItem> presentationOrder({
    required Iterable<WorkspaceEvidenceItem> items,
    required List<String> orderedCapturedEvidenceIds,
    Set<String> organizeCreatedIds = const {},
    String? incidentId,
  }) {
    if (incidentId != null && incidentId.isEmpty) {
      return const [];
    }
    final scoped = <WorkspaceEvidenceItem>[
      for (final item in items)
        if (incidentId == null || item.belongsToIncident(incidentId)) item,
    ];
    if (scoped.isEmpty) {
      return const [];
    }

    final byId = <String, WorkspaceEvidenceItem>{
      for (final item in scoped) item.id: item,
    };
    final placed = <String>{};
    final canonical = <WorkspaceEvidenceItem>[];
    for (final id in orderedCapturedEvidenceIds) {
      final item = byId[id];
      if (item == null) {
        continue;
      }
      if (classify(
            item: item,
            orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
            organizeCreatedIds: organizeCreatedIds,
          ) !=
          OrganizeChronologyEligibility.canonical) {
        continue;
      }
      canonical.add(item);
      placed.add(id);
    }

    final uncanonical = <WorkspaceEvidenceItem>[];
    final legacy = <WorkspaceEvidenceItem>[];
    final context = <WorkspaceEvidenceItem>[];
    for (final item in scoped) {
      if (placed.contains(item.id)) {
        continue;
      }
      switch (classify(
        item: item,
        orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
        organizeCreatedIds: organizeCreatedIds,
      )) {
        case OrganizeChronologyEligibility.canonical:
          break;
        case OrganizeChronologyEligibility.uncanonicalChronological:
          uncanonical.add(item);
        case OrganizeChronologyEligibility.legacyFixed:
          legacy.add(item);
        case OrganizeChronologyEligibility.context:
          context.add(item);
      }
    }
    uncanonical.sort(fallbackCompare);
    legacy.sort(fallbackCompare);
    context.sort(fallbackCompare);

    return [...canonical, ...uncanonical, ...legacy, ...context];
  }
}
