import 'verification_model.dart';
import 'workspace_evidence_item.dart';

/// Canonical evidence types for [EvidenceArtifactCard] presentation.
enum EvidenceArtifactType {
  photo,
  video,
  voiceRecording,
  note,
  document;

  String get label => switch (this) {
        EvidenceArtifactType.photo => 'Photo',
        EvidenceArtifactType.video => 'Video',
        EvidenceArtifactType.voiceRecording => 'Voice Recording',
        EvidenceArtifactType.note => 'Note',
        EvidenceArtifactType.document => 'Document',
      };

  static EvidenceArtifactType fromWorkspaceKind(WorkspaceEvidenceKind kind) =>
      switch (kind) {
        WorkspaceEvidenceKind.image => EvidenceArtifactType.photo,
        WorkspaceEvidenceKind.video => EvidenceArtifactType.video,
        WorkspaceEvidenceKind.voice => EvidenceArtifactType.voiceRecording,
        WorkspaceEvidenceKind.note => EvidenceArtifactType.note,
        WorkspaceEvidenceKind.attachment => EvidenceArtifactType.document,
        WorkspaceEvidenceKind.witness => EvidenceArtifactType.note,
      };
}

/// Presentation model for a single preserved evidence artifact.
///
/// Reusable across Evidence Map, detail views, reports, and sharing flows.
/// Extension fields are reserved for future relationship, custody, and AI badges.
class EvidenceArtifactModel {
  const EvidenceArtifactModel({
    required this.id,
    required this.type,
    required this.preservedAt,
    required this.integrityVerified,
    required this.verification,
    required this.contextEnriched,
    this.notePreview,
    this.fileName,
    this.sourceEvidenceId,
    this.thumbnailPath,
    this.filePath,
    this.downloadUrl,
  });

  final String id;
  final EvidenceArtifactType type;
  final DateTime preservedAt;
  final bool integrityVerified;
  final VerificationModel verification;
  final bool contextEnriched;
  final String? notePreview;
  final String? fileName;

  /// Reserved for relationship and chain-of-custody visualisation.
  final String? sourceEvidenceId;

  /// Local/network preview paths — same sources as Journey thumbnails.
  final String? thumbnailPath;
  final String? filePath;
  final String? downloadUrl;

  /// Image path for Evidence Map photo/video thumbs (cached thumb preferred).
  ///
  /// Mirrors Journey [LivingEvidencePreview] resolution. Never treats
  /// note/voice/document primary files as photo previews.
  String? get previewImagePath {
    if (type == EvidenceArtifactType.note ||
        type == EvidenceArtifactType.voiceRecording ||
        type == EvidenceArtifactType.document) {
      return null;
    }

    final candidates = <String?>[
      thumbnailPath,
      if (type == EvidenceArtifactType.photo) downloadUrl,
      if (type == EvidenceArtifactType.photo) filePath,
    ];
    for (final path in candidates) {
      if (path == null || path.isEmpty) {
        continue;
      }
      if (_isNetworkUrl(path)) {
        return path;
      }
      if (_looksLikeImagePath(path)) {
        return path;
      }
    }
    return null;
  }

  /// Safe image thumb for document cards when the attachment itself is an image.
  String? get documentImagePreviewPath {
    if (type != EvidenceArtifactType.document) {
      return null;
    }
    for (final path in <String?>[thumbnailPath, filePath]) {
      if (path == null || path.isEmpty) {
        continue;
      }
      if (!_isNetworkUrl(path) && _looksLikeImagePath(path)) {
        return path;
      }
    }
    return null;
  }

  static bool _isNetworkUrl(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static bool _looksLikeImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic');
  }

  factory EvidenceArtifactModel.fromWorkspaceItem(WorkspaceEvidenceItem item) {
    return EvidenceArtifactModel(
      id: item.id,
      type: EvidenceArtifactType.fromWorkspaceKind(item.kind),
      preservedAt: item.lastPreservedAt,
      integrityVerified: item.integrityVerified,
      verification: item.verification,
      contextEnriched:
          item.relatedEvidenceIds.isNotEmpty || item.isContextual,
      notePreview: item.notePreview,
      fileName: item.fileName,
      thumbnailPath: item.thumbnailPath,
      filePath: item.filePath,
      downloadUrl: item.downloadUrl,
    );
  }
}
