/// Canonical Firestore / Storage path helpers (Sprint 4D).
abstract final class FirestorePaths {
  static String user(String uid) => 'users/$uid';

  static String incidents(String uid) => 'users/$uid/incidents';

  /// User-created Vault groupings of incident IDs. Not intra-incident
  /// [evidenceCollections].
  static String incidentCollections(String uid) =>
      'users/$uid/incidentCollections';

  static String incidentCollection(String uid, String collectionId) =>
      'users/$uid/incidentCollections/$collectionId';

  static String incident(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId';

  static String evidenceCollection(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/evidence';

  static String evidenceDoc(
    String uid,
    String incidentId,
    String evidenceId,
  ) =>
      'users/$uid/incidents/$incidentId/evidence/$evidenceId';

  static String timelineAnchors(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/timelineAnchors';

  static String relationshipGroups(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/relationshipGroups';

  /// Organize-stage Evidence Collections (Sprint 5B).
  static String evidenceCollections(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/evidenceCollections';

  static String relationships(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/relationships';

  static String narrativeEvents(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/narrativeEvents';

  static String reconstructionNotes(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/reconstructionNotes';

  static String participants(String uid, String incidentId) =>
      'users/$uid/incidents/$incidentId/participants';

  /// Storage folders — single canonical hierarchy.
  static const photos = 'photos';
  static const videos = 'videos';
  static const voice = 'voice';
  static const attachments = 'attachments';
  static const thumbnails = 'thumbnails';
}
