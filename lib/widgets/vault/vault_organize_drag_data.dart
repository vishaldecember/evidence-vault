/// Payload for Vault organize drag. Phase 3 carries an incident ID only.
///
/// A future collection target can be added here without a generic grouping
/// domain type.
class VaultOrganizeDragData {
  const VaultOrganizeDragData.incident(this.incidentId);

  final String incidentId;
}
