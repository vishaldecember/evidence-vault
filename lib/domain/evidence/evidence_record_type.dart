import 'captured_evidence_type.dart';
import 'supporting_evidence_type.dart';
import '../../models/workspace_capture_mode.dart';

/// Unified evidence type for lifecycle records (captured + supporting).
enum EvidenceRecordType {
  photo,
  video,
  voice,
  note,
  document,
  witness,
  other;

  String get label => switch (this) {
        EvidenceRecordType.photo => 'Photo',
        EvidenceRecordType.video => 'Video',
        EvidenceRecordType.voice => 'Voice',
        EvidenceRecordType.note => 'Note',
        EvidenceRecordType.document => 'Document',
        EvidenceRecordType.witness => 'Witness',
        EvidenceRecordType.other => 'Evidence',
      };

  static EvidenceRecordType fromCaptured(CapturedEvidenceType type) =>
      switch (type) {
        CapturedEvidenceType.photo => EvidenceRecordType.photo,
        CapturedEvidenceType.video => EvidenceRecordType.video,
        CapturedEvidenceType.voice => EvidenceRecordType.voice,
      };

  static EvidenceRecordType fromSupporting(SupportingEvidenceType type) =>
      switch (type) {
        SupportingEvidenceType.note => EvidenceRecordType.note,
        SupportingEvidenceType.pdf ||
        SupportingEvidenceType.document ||
        SupportingEvidenceType.attachment =>
          EvidenceRecordType.document,
        SupportingEvidenceType.witnessStatement => EvidenceRecordType.witness,
      };

  static EvidenceRecordType fromCaptureMode(WorkspaceCaptureMode mode) =>
      switch (mode) {
        WorkspaceCaptureMode.photo => EvidenceRecordType.photo,
        WorkspaceCaptureMode.video => EvidenceRecordType.video,
        WorkspaceCaptureMode.voice => EvidenceRecordType.voice,
        WorkspaceCaptureMode.note => EvidenceRecordType.note,
        WorkspaceCaptureMode.file => EvidenceRecordType.document,
      };
}
