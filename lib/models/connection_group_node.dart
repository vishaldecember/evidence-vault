import '../domain/relationship/relationship_group.dart';
import 'workspace_evidence_item.dart';

/// One captured artifact and supporting members within a relationship group.
class ConnectionGroupCapturedEntry {
  const ConnectionGroupCapturedEntry({
    required this.captured,
    required this.supportingItems,
  });

  final WorkspaceEvidenceItem captured;
  final List<WorkspaceEvidenceItem> supportingItems;
}

/// Presentation view of one [RelationshipGroup] for the Connections Workspace.
class ConnectionGroupNode {
  const ConnectionGroupNode({
    required this.group,
    required this.capturedEntries,
    required this.standaloneSupporting,
  });

  final RelationshipGroup group;
  final List<ConnectionGroupCapturedEntry> capturedEntries;
  final List<WorkspaceEvidenceItem> standaloneSupporting;

  int get evidenceCount =>
      capturedEntries.length +
      capturedEntries.fold<int>(
        0,
        (total, entry) => total + entry.supportingItems.length,
      ) +
      standaloneSupporting.length;
}
