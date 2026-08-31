import '../../domain/organize/organize_context_anchor.dart';
import '../../repositories/incident_store.dart';

/// Incident-scoped Organize context anchors. Persisted per incident as
/// explicit user snaps only. Does not write evidence, relationships,
/// collections, or chronology.
class OrganizeContextAnchorStore {
  OrganizeContextAnchorStore._();

  static final OrganizeContextAnchorStore instance =
      OrganizeContextAnchorStore._();

  /// One context item → one captured moment. Replaces a prior anchor for the
  /// same [contextEvidenceId]. Does not modify evidence records.
  OrganizeContextAnchor? setAnchor({
    required IncidentStore store,
    required String contextEvidenceId,
    required String capturedEvidenceId,
  }) {
    final contextId = contextEvidenceId.trim();
    final capturedId = capturedEvidenceId.trim();
    if (contextId.isEmpty || capturedId.isEmpty || contextId == capturedId) {
      return null;
    }
    if (!_exists(store, contextId) || !_exists(store, capturedId)) {
      return null;
    }

    store.organizeContextAnchors.removeWhere(
      (anchor) => anchor.contextEvidenceId == contextId,
    );
    final anchor = OrganizeContextAnchor(
      contextEvidenceId: contextId,
      capturedEvidenceId: capturedId,
    );
    store.organizeContextAnchors.add(anchor);
    return anchor;
  }

  void clearAnchor({
    required IncidentStore store,
    required String contextEvidenceId,
  }) {
    store.organizeContextAnchors.removeWhere(
      (anchor) => anchor.contextEvidenceId == contextEvidenceId.trim(),
    );
  }

  OrganizeContextAnchor? anchorForContext({
    required IncidentStore store,
    required String contextEvidenceId,
  }) {
    final id = contextEvidenceId.trim();
    for (final anchor in store.organizeContextAnchors) {
      if (anchor.contextEvidenceId == id) {
        return anchor;
      }
    }
    return null;
  }

  List<OrganizeContextAnchor> anchorsForCaptured({
    required IncidentStore store,
    required String capturedEvidenceId,
  }) {
    final id = capturedEvidenceId.trim();
    return [
      for (final anchor in store.organizeContextAnchors)
        if (anchor.capturedEvidenceId == id) anchor,
    ];
  }

  static bool _exists(IncidentStore store, String evidenceId) {
    for (final item in store.capturedEvidence) {
      if (item.id == evidenceId) {
        return true;
      }
    }
    for (final item in store.supportingEvidence) {
      if (item.id == evidenceId) {
        return true;
      }
    }
    return false;
  }
}
