import '../../models/workspace_evidence_item.dart';

/// Organize presentation spine membership.
///
/// Floating / wobble / drag-to-place is **origin only**: Voice, Text, and File
/// created from the Organize toolbar ([organizeCreatedIds]). Capture-origin
/// evidence — including files, notes, and voice from Home / Capture — stays on
/// the chronological spine even when Timeline Role is context.
///
/// Presentation only — never writes chronology, origin sets, or placement.
abstract final class OrganizeSpineClassification {
  static bool isToolbarCreated(
    String evidenceId, {
    required Set<String> organizeCreatedIds,
  }) {
    return organizeCreatedIds.contains(evidenceId.trim());
  }

  static bool isContextSpine({
    required WorkspaceEvidenceItem item,
    Set<String> organizeCreatedIds = const {},
  }) {
    return isToolbarCreated(item.id, organizeCreatedIds: organizeCreatedIds);
  }

  static bool isChronologicalSpine({
    required WorkspaceEvidenceItem item,
    Set<String> organizeCreatedIds = const {},
  }) {
    return !isContextSpine(
      item: item,
      organizeCreatedIds: organizeCreatedIds,
    );
  }
}
