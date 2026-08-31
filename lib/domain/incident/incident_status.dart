/// Operational lifecycle for an [Incident].
enum IncidentStatus {
  draft,
  active,
  paused,
  finalized,
  archived,
  recentlyDeleted;

  String get label => switch (this) {
        IncidentStatus.draft => 'Draft',
        IncidentStatus.active => 'Active',
        IncidentStatus.paused => 'Paused',
        IncidentStatus.finalized => 'Finalized',
        IncidentStatus.archived => 'Archived',
        IncidentStatus.recentlyDeleted => 'Recently Deleted',
      };
}
