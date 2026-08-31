import '../../models/workspace_evidence_item.dart';

/// Display labels for Timeline Workspace entries.
abstract final class TimelineEvidenceLabels {
  static String capturedLabel(WorkspaceEvidenceItem item) =>
      '${capturedEmoji(item.kind)} ${item.kind.label}';

  static String supportingLabel(WorkspaceEvidenceItem item) =>
      '${supportingEmoji(item.kind)} ${_supportingKindLabel(item)}';

  static String capturedEmoji(WorkspaceEvidenceKind kind) => switch (kind) {
        WorkspaceEvidenceKind.image => '📷',
        WorkspaceEvidenceKind.video => '🎥',
        WorkspaceEvidenceKind.voice => '🎤',
        _ => '📄',
      };

  static String supportingEmoji(WorkspaceEvidenceKind kind) => switch (kind) {
        WorkspaceEvidenceKind.note => '📝',
        WorkspaceEvidenceKind.attachment => '📄',
        WorkspaceEvidenceKind.witness => '👤',
        _ => '📎',
      };

  static String _supportingKindLabel(WorkspaceEvidenceItem item) {
    if (item.isContextual && item.kind == WorkspaceEvidenceKind.note) {
      return 'Context';
    }

    return switch (item.kind) {
      WorkspaceEvidenceKind.note => 'Note',
      WorkspaceEvidenceKind.attachment => 'PDF',
      WorkspaceEvidenceKind.witness => 'Witness',
      _ => item.kind.label,
    };
  }
}
