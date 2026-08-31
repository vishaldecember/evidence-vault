import '../../domain/vault/incident_collection.dart';
import '../../models/library_incident_summary.dart';

/// Presentation row in Vault Recent. Not a persisted entity.
sealed class VaultRecentEntry {
  const VaultRecentEntry();
}

class VaultRecentIncidentEntry extends VaultRecentEntry {
  const VaultRecentIncidentEntry(this.incident);

  final LibraryIncidentSummary incident;
}

class VaultRecentCollectionEntry extends VaultRecentEntry {
  const VaultRecentCollectionEntry(this.collection);

  final IncidentCollection collection;
}

/// Places each collection at the first active member in library order.
/// Member incidents stay in [IncidentLibraryService]; they are only hidden
/// as standalone tiles.
List<VaultRecentEntry> composeVaultRecent({
  required List<LibraryIncidentSummary> activeIncidents,
  required List<IncidentCollection> collections,
}) {
  final byMember = <String, IncidentCollection>{};
  for (final collection in collections) {
    for (final id in collection.memberIncidentIds) {
      byMember.putIfAbsent(id, () => collection);
    }
  }
  final shown = <String>{};
  final entries = <VaultRecentEntry>[];
  for (final incident in activeIncidents) {
    final collection = byMember[incident.id];
    if (collection == null) {
      entries.add(VaultRecentIncidentEntry(incident));
      continue;
    }
    if (shown.add(collection.id)) {
      entries.add(VaultRecentCollectionEntry(collection));
    }
  }
  return entries;
}
