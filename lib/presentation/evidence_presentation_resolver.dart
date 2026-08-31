import '../models/evidence_artifact_model.dart';
import '../models/evidence_record_model.dart';
import '../models/workspace_evidence_item.dart';
import '../services/storage/file_attachment_classifier.dart';
import '../widgets/evidence_inspector/evidence_preview_renderer.dart';

/// UI-only presentation kind. Does not change chronology or Evidence identity.
enum EvidencePresentationKind {
  photo,
  video,
  voice,
  note,
  document,
  pdf,
  witness,
}

/// Resolved presentation for one [WorkspaceEvidenceItem].
///
/// Semantic [kind] stays on the item. [previewKind] may be video for a
/// file-attached video without converting it to chronology video.
class EvidencePresentation {
  const EvidencePresentation({
    required this.semanticKind,
    required this.previewKind,
    this.thumbnailPath,
    this.playbackPath,
    required this.metadata,
  });

  final WorkspaceEvidenceKind semanticKind;
  final EvidencePresentationKind previewKind;
  final String? thumbnailPath;
  final String? playbackPath;
  final EvidenceRecordMetadata metadata;

  bool get isChronologyVideo => semanticKind == WorkspaceEvidenceKind.video;

  EvidenceArtifactType get artifactType => switch (previewKind) {
        EvidencePresentationKind.photo => EvidenceArtifactType.photo,
        EvidencePresentationKind.video => EvidenceArtifactType.video,
        EvidencePresentationKind.voice => EvidenceArtifactType.voiceRecording,
        EvidencePresentationKind.note ||
        EvidencePresentationKind.witness =>
          EvidenceArtifactType.note,
        EvidencePresentationKind.document ||
        EvidencePresentationKind.pdf =>
          EvidenceArtifactType.document,
      };

  EvidencePreviewRenderer get renderer {
    if (previewKind == EvidencePresentationKind.pdf) {
      return EvidencePreviewRegistry.resolvePdf();
    }
    return EvidencePreviewRegistry.resolve(artifactType);
  }
}

/// Single presentation boundary over [WorkspaceEvidenceItem].
///
/// Does not mutate Evidence, incident identity, or persist paths.
abstract final class EvidencePresentationResolver {
  static EvidencePresentation resolve(WorkspaceEvidenceItem item) {
    final previewKind = _previewKind(item);
    return EvidencePresentation(
      semanticKind: item.kind,
      previewKind: previewKind,
      thumbnailPath: _thumbnailPath(item, previewKind),
      playbackPath: _playbackPath(item, previewKind),
      metadata: resolveMetadata(item),
    );
  }

  static String? resolveThumbnail(WorkspaceEvidenceItem item) =>
      resolve(item).thumbnailPath;

  static EvidencePreviewRenderer resolvePreview(WorkspaceEvidenceItem item) =>
      resolve(item).renderer;

  static EvidenceRecordMetadata resolveMetadata(WorkspaceEvidenceItem item) =>
      EvidenceRecordMetadata.forItem(item);

  static EvidencePreviewRenderer resolveCompleteRecordPresentation(
    WorkspaceEvidenceItem item,
  ) =>
      resolve(item).renderer;

  static EvidencePresentationKind _previewKind(WorkspaceEvidenceItem item) {
    return switch (item.kind) {
      WorkspaceEvidenceKind.image => EvidencePresentationKind.photo,
      WorkspaceEvidenceKind.video => EvidencePresentationKind.video,
      WorkspaceEvidenceKind.voice => EvidencePresentationKind.voice,
      WorkspaceEvidenceKind.note => EvidencePresentationKind.note,
      WorkspaceEvidenceKind.witness => EvidencePresentationKind.witness,
      WorkspaceEvidenceKind.attachment => _isVideoFile(item)
          ? EvidencePresentationKind.video
          : _isPdfFile(item)
              ? EvidencePresentationKind.pdf
              : EvidencePresentationKind.document,
    };
  }

  static bool _isVideoFile(WorkspaceEvidenceItem item) {
    return FileAttachmentClassifier.isVideo(
      fileName: item.fileName ?? item.filePath ?? '',
      mimeType: item.mimeType,
    );
  }

  static bool _isPdfFile(WorkspaceEvidenceItem item) {
    return FileAttachmentClassifier.isPdf(
      fileName: item.fileName ?? item.filePath ?? '',
      mimeType: item.mimeType,
    );
  }

  static String? _thumbnailPath(
    WorkspaceEvidenceItem item,
    EvidencePresentationKind previewKind,
  ) {
    final candidates = <String?>[
      item.thumbnailPath,
      if (previewKind == EvidencePresentationKind.photo) item.downloadUrl,
      if (previewKind == EvidencePresentationKind.photo) item.filePath,
    ];
    for (final path in candidates) {
      if (path == null || path.isEmpty) {
        continue;
      }
      if (_isNetworkUrl(path) || _looksLikeImage(path)) {
        return path;
      }
    }
    return null;
  }

  static String? _playbackPath(
    WorkspaceEvidenceItem item,
    EvidencePresentationKind previewKind,
  ) {
    return switch (previewKind) {
      EvidencePresentationKind.photo ||
      EvidencePresentationKind.video ||
      EvidencePresentationKind.voice =>
        item.filePath ?? item.thumbnailPath,
      EvidencePresentationKind.document ||
      EvidencePresentationKind.pdf =>
        item.filePath,
      EvidencePresentationKind.note ||
      EvidencePresentationKind.witness =>
        null,
    };
  }

  static bool _looksLikeImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic');
  }

  static bool _isNetworkUrl(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}
