import 'context_type.dart';
import 'workspace_evidence_item.dart';

/// Presentation model for one item in the Context Timeline.
class ContextItem {
  const ContextItem({
    required this.id,
    required this.type,
    required this.title,
    required this.addedAt,
    this.updatedAt,
    this.preview,
  });

  final String id;
  final ContextType type;
  final String title;
  final DateTime addedAt;
  final DateTime? updatedAt;
  final String? preview;

  String get displayTitle {
    if (preview != null && preview!.trim().isNotEmpty) {
      return preview!.trim();
    }
    return title;
  }

  factory ContextItem.fromWorkspaceItem(WorkspaceEvidenceItem item) {
    return ContextItem(
      id: item.id,
      type: ContextType.fromWorkspaceKind(item.kind),
      title: item.title,
      addedAt: item.lastPreservedAt,
      updatedAt: item.updatedAt,
      preview: item.notePreview ?? item.fileName,
    );
  }
}
