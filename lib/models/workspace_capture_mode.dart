import 'package:flutter/material.dart';

enum WorkspaceCaptureMode {
  photo,
  video,
  voice,
  note,
  file;

  String get label => switch (this) {
        WorkspaceCaptureMode.photo => 'Photo',
        WorkspaceCaptureMode.video => 'Video',
        WorkspaceCaptureMode.voice => 'Voice',
        WorkspaceCaptureMode.note => 'Note',
        WorkspaceCaptureMode.file => 'File',
      };

  /// Screen reader label for workspace capture actions.
  String get semanticLabel => switch (this) {
        WorkspaceCaptureMode.photo => 'Capture photo evidence',
        WorkspaceCaptureMode.video => 'Capture video evidence',
        WorkspaceCaptureMode.voice => 'Record voice evidence',
        WorkspaceCaptureMode.note => 'Add written note',
        WorkspaceCaptureMode.file => 'Attach file',
      };

  IconData get icon => switch (this) {
        WorkspaceCaptureMode.photo => Icons.photo_camera_outlined,
        WorkspaceCaptureMode.video => Icons.videocam_outlined,
        WorkspaceCaptureMode.voice => Icons.mic_outlined,
        WorkspaceCaptureMode.note => Icons.edit_note_outlined,
        WorkspaceCaptureMode.file => Icons.attach_file_outlined,
      };

  String get sprintPlaceholderMessage => switch (this) {
        WorkspaceCaptureMode.photo => 'Camera capture coming in Sprint 4',
        WorkspaceCaptureMode.video => 'Video capture coming in Sprint 4',
        WorkspaceCaptureMode.voice => 'Voice capture coming in Sprint 4',
        WorkspaceCaptureMode.note => 'Note capture coming in Sprint 4',
        WorkspaceCaptureMode.file => 'File capture coming in Sprint 4',
      };
}
