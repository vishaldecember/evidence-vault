import '../../repositories/incident_store.dart';

/// Library-facing split of an incident's working set.
///
/// Evidence is captured Photo / Video / Voice / Note / File that belongs to
/// the incident chronology. Context is Organise-attached material
/// (`organizeCreatedEvidenceIds` and parent-linked contextual supporting
/// items). The two sets never overlap.
abstract final class IncidentComposition {
  const IncidentComposition._();

  static bool isContextItem({
    required String evidenceId,
    required bool isContextual,
    required Set<String> organizeCreatedIds,
  }) {
    return organizeCreatedIds.contains(evidenceId) || isContextual;
  }

  static ({int evidenceCount, int contextEnrichedCount}) fromStore(
    IncidentStore store,
  ) {
    final organizeIds = store.organizeCreatedEvidenceIds;
    var evidenceCount = 0;
    var contextEnrichedCount = 0;

    for (final item in store.capturedEvidence) {
      if (organizeIds.contains(item.id)) {
        contextEnrichedCount++;
      } else {
        evidenceCount++;
      }
    }
    for (final item in store.supportingEvidence) {
      if (isContextItem(
        evidenceId: item.id,
        isContextual: item.isContextual,
        organizeCreatedIds: organizeIds,
      )) {
        contextEnrichedCount++;
      } else {
        evidenceCount++;
      }
    }

    return (
      evidenceCount: evidenceCount,
      contextEnrichedCount: contextEnrichedCount,
    );
  }
}
