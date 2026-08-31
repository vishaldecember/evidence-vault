import 'package:flutter/material.dart';

import '../../models/evidence_artifact_model.dart';
import '../../models/evidence_record_model.dart';
import 'renderers/attachment_evidence_renderer.dart';
import 'renderers/pdf_evidence_renderer.dart';
import 'renderers/photo_evidence_renderer.dart';
import 'renderers/text_evidence_renderer.dart';
import 'renderers/video_evidence_renderer.dart';
import 'renderers/voice_evidence_renderer.dart';

/// Shared inputs for every Evidence Inspector preview renderer.
class EvidencePreviewContext {
  const EvidencePreviewContext({
    required this.record,
    required this.availableSize,
    this.onNoteBodyChanged,
  });

  final EvidenceRecordModel record;
  final Size availableSize;
  final ValueChanged<String>? onNoteBodyChanged;
}

/// Type-specific preview surface for the Evidence Inspector.
///
/// Register new kinds (Witness, Location, AI evidence) by adding a renderer
/// and a [EvidencePreviewRegistry] mapping — avoid expanding modal switches.
abstract class EvidencePreviewRenderer {
  const EvidencePreviewRenderer();

  Widget build(BuildContext context, EvidencePreviewContext preview);
}

/// Starts Inspector playback only after the media source is ready.
///
/// Photos, notes, and documents must not call this. Failed init must not.
abstract final class InspectorAutoplay {
  InspectorAutoplay._();

  static Future<void> startWhenReady({
    required Future<void> Function() seekToStart,
    required Future<void> Function() play,
  }) async {
    await seekToStart();
    await play();
  }
}

/// Resolves the renderer for an [EvidenceArtifactType].
abstract final class EvidencePreviewRegistry {
  static EvidencePreviewRenderer resolve(EvidenceArtifactType type) {
    return switch (type) {
      EvidenceArtifactType.photo => const PhotoEvidenceRenderer(),
      EvidenceArtifactType.video => const VideoEvidenceRenderer(),
      EvidenceArtifactType.voiceRecording => const VoiceEvidenceRenderer(),
      EvidenceArtifactType.note => const TextEvidenceRenderer(),
      EvidenceArtifactType.document => const AttachmentEvidenceRenderer(),
    };
  }

  /// PDF is presentation-only. Semantic kind stays attachment; artifact type
  /// stays document so Evidence schema is unchanged.
  static EvidencePreviewRenderer resolvePdf() => const PdfEvidenceRenderer();
}
