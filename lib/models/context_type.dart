import 'package:flutter/material.dart';

import 'workspace_capture_mode.dart';
import 'workspace_evidence_item.dart';

/// Canonical context types for the Context Timeline.
///
/// Phase 1 supports note, voice, photo, video, and document.
/// Future types (witness, location, link, aiSummary, reflection) extend
/// this enum without changing existing presentation code.
enum ContextType {
  note,
  voiceRecording,
  photo,
  video,
  document;

  String get label => switch (this) {
        ContextType.note => 'Note',
        ContextType.voiceRecording => 'Voice Recording',
        ContextType.photo => 'Photo',
        ContextType.video => 'Video',
        ContextType.document => 'Document',
      };

  IconData get icon => switch (this) {
        ContextType.note => Icons.edit_note_outlined,
        ContextType.voiceRecording => Icons.mic_outlined,
        ContextType.photo => Icons.photo_outlined,
        ContextType.video => Icons.videocam_outlined,
        ContextType.document => Icons.insert_drive_file_outlined,
      };

  /// Bottom sheet action label for adding this context type.
  String get addActionLabel => switch (this) {
        ContextType.note => 'Add Note',
        ContextType.voiceRecording => 'Record Voice',
        ContextType.photo => 'Capture Photo',
        ContextType.video => 'Record Video',
        ContextType.document => 'Attach Document',
      };

  static ContextType fromWorkspaceKind(WorkspaceEvidenceKind kind) =>
      switch (kind) {
        WorkspaceEvidenceKind.note => ContextType.note,
        WorkspaceEvidenceKind.voice => ContextType.voiceRecording,
        WorkspaceEvidenceKind.image => ContextType.photo,
        WorkspaceEvidenceKind.video => ContextType.video,
        WorkspaceEvidenceKind.attachment => ContextType.document,
        WorkspaceEvidenceKind.witness => ContextType.note,
      };

  static ContextType fromCaptureMode(WorkspaceCaptureMode mode) =>
      switch (mode) {
        WorkspaceCaptureMode.note => ContextType.note,
        WorkspaceCaptureMode.voice => ContextType.voiceRecording,
        WorkspaceCaptureMode.photo => ContextType.photo,
        WorkspaceCaptureMode.video => ContextType.video,
        WorkspaceCaptureMode.file => ContextType.document,
      };

  static WorkspaceCaptureMode toCaptureMode(ContextType type) => switch (type) {
        ContextType.note => WorkspaceCaptureMode.note,
        ContextType.voiceRecording => WorkspaceCaptureMode.voice,
        ContextType.photo => WorkspaceCaptureMode.photo,
        ContextType.video => WorkspaceCaptureMode.video,
        ContextType.document => WorkspaceCaptureMode.file,
      };

  /// Phase 1 context types available in the Add Context flow.
  static const List<ContextType> phase1 = [
    ContextType.note,
    ContextType.voiceRecording,
    ContextType.photo,
    ContextType.video,
    ContextType.document,
  ];
}
