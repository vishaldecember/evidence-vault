import '../../models/library_incident_summary.dart';

/// Presentation row for a collection member ID.
///
/// [summary] is the existing Library projection. Null means the ID is
/// stale or not in the current library — not a fabricated Incident.
class CollectionMemberView {
  const CollectionMemberView({
    required this.incidentId,
    this.summary,
  });

  final String incidentId;
  final LibraryIncidentSummary? summary;

  bool get isAvailable => summary != null;
}

/// Resolves persisted member IDs against [IncidentLibraryService] summaries.
///
/// Order follows [memberIncidentIds]. Does not fetch evidence or invent
/// Incident records.
List<CollectionMemberView> resolveCollectionMembers({
  required Iterable<String> memberIncidentIds,
  required Iterable<LibraryIncidentSummary> summaries,
}) {
  final byId = <String, LibraryIncidentSummary>{
    for (final summary in summaries) summary.id: summary,
  };
  return [
    for (final raw in memberIncidentIds)
      CollectionMemberView(
        incidentId: raw,
        summary: _operationalSummary(byId[raw]),
      ),
  ];
}

LibraryIncidentSummary? _operationalSummary(LibraryIncidentSummary? summary) {
  if (summary == null || summary.isRecentlyDeleted) {
    return null;
  }
  return summary;
}
