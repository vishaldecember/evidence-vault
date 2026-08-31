import '../../models/library_incident_summary.dart';

/// Home journey-card state derived from the incident library.
///
/// Not a store. Callers pass the current library list plus the open session
/// identity so the card can overlay live title/counts only when IDs match.
enum HomeIncidentDisplayKind {
  /// No real incident exists — first-incident onboarding.
  firstIncident,

  /// Real incidents exist, but none are in-progress / continuable.
  libraryOnly,

  /// A real in-progress incident can be continued.
  continuePreserving,
}

/// Resolved Home incident presentation — library is the existence source.
class HomeIncidentDisplayState {
  const HomeIncidentDisplayState({
    required this.kind,
    required this.visibleLibraryIncidents,
    this.continueIncident,
  });

  final HomeIncidentDisplayKind kind;
  final List<LibraryIncidentSummary> visibleLibraryIncidents;
  final LibraryIncidentSummary? continueIncident;

  /// A library row is a real incident Home may show or continue.
  ///
  /// Empty untitled drafts (ensureIncident / session shell leftovers) are not
  /// valid — they must not populate Continue Preserving or incident metadata.
  static bool isValidIncident(LibraryIncidentSummary incident) {
    if (incident.id.trim().isEmpty) {
      return false;
    }
    if (incident.evidenceCount > 0) {
      return true;
    }
    final title = incident.title.trim();
    return title.isNotEmpty && title != 'Untitled Incident';
  }

  /// Derives Home state from the library. Session data may enrich a matching
  /// library incident; it must never invent a card when the library is empty.
  static HomeIncidentDisplayState resolve({
    required List<LibraryIncidentSummary> libraryIncidents,
    required String sessionIncidentId,
    required String sessionTitle,
    required int sessionEvidenceCount,
    required int sessionNarrativeCount,
  }) {
    final valid = [
      for (final incident in libraryIncidents)
        if (isValidIncident(incident)) incident,
    ];

    if (valid.isEmpty) {
      return const HomeIncidentDisplayState(
        kind: HomeIncidentDisplayKind.firstIncident,
        visibleLibraryIncidents: [],
      );
    }

    final sessionId = sessionIncidentId.trim();
    LibraryIncidentSummary? continueIncident;

    if (sessionId.isNotEmpty) {
      for (final incident in valid) {
        if (incident.id == sessionId && incident.isInProgress) {
          continueIncident = _overlayMatchingSession(
            library: incident,
            sessionTitle: sessionTitle,
            sessionEvidenceCount: sessionEvidenceCount,
            sessionNarrativeCount: sessionNarrativeCount,
          );
          break;
        }
      }
    }

    continueIncident ??= _bestInProgress(valid);

    if (continueIncident != null) {
      return HomeIncidentDisplayState(
        kind: HomeIncidentDisplayKind.continuePreserving,
        visibleLibraryIncidents: valid,
        continueIncident: continueIncident,
      );
    }

    return HomeIncidentDisplayState(
      kind: HomeIncidentDisplayKind.libraryOnly,
      visibleLibraryIncidents: valid,
    );
  }

  static LibraryIncidentSummary _overlayMatchingSession({
    required LibraryIncidentSummary library,
    required String sessionTitle,
    required int sessionEvidenceCount,
    required int sessionNarrativeCount,
  }) {
    return LibraryIncidentSummary(
      id: library.id,
      title: sessionTitle.trim().isNotEmpty ? sessionTitle.trim() : library.title,
      evidenceCount: sessionEvidenceCount > 0
          ? sessionEvidenceCount
          : library.evidenceCount,
      contextEnrichedCount: library.contextEnrichedCount,
      integrityVerified: library.integrityVerified,
      lastPreserved: library.lastPreserved,
      narrativeCount: sessionNarrativeCount,
      isInProgress: !library.isArchived && !library.isRecentlyDeleted,
      isArchived: library.isArchived,
      isRecentlyDeleted: library.isRecentlyDeleted,
      deletedAt: library.deletedAt,
      createdAt: library.createdAt,
      updatedAt: library.updatedAt,
    );
  }

  static LibraryIncidentSummary? _bestInProgress(
    List<LibraryIncidentSummary> valid,
  ) {
    LibraryIncidentSummary? best;
    for (final incident in valid) {
      if (!incident.isInProgress || incident.isRecentlyDeleted) {
        continue;
      }
      if (best == null ||
          incident.evidenceCount > best.evidenceCount ||
          (incident.evidenceCount == best.evidenceCount &&
              (incident.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .isAfter(
                best.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ))) {
        best = incident;
      }
    }
    return best;
  }
}
