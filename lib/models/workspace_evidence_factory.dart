import 'package:uuid/uuid.dart';

import 'relationship_type.dart';
import 'verification_factory.dart';
import 'workspace_capture_mode.dart';
import 'workspace_evidence_item.dart';

/// Factory helpers for workspace evidence presentation items.
///
/// Evidence IDs are immutable UUIDs. Never reuse sequential keys such as
/// `ws-evidence-1` — those collide after restore / hot restart and produce
/// duplicate [ValueKey]s in the Incident Journey grid.
abstract final class WorkspaceEvidenceFactory {
  static const _uuid = Uuid();

  /// Deterministic counter reserved for widget/unit tests only.
  static int _testCounter = 0;
  static bool _useDeterministicTestIds = false;

  static String _nextId({required String prefix}) {
    if (_useDeterministicTestIds) {
      _testCounter += 1;
      return '$prefix-$_testCounter';
    }
    return '$prefix-${_uuid.v4()}';
  }

  static String nextEvidenceId() => _nextId(prefix: 'ev');

  static String nextRelationshipId() => _nextId(prefix: 'rel');

  static String nextRelationshipGroupId() => _nextId(prefix: 'grp');

  static String nextParticipantId() => _nextId(prefix: 'par');

  static WorkspaceEvidenceItem createFromCapture(
    WorkspaceCaptureMode mode, {
    bool isContextual = false,
  }) {
    final now = DateTime.now();
    final kind = WorkspaceEvidenceKind.fromCaptureMode(mode);

    return WorkspaceEvidenceItem(
      id: nextEvidenceId(),
      kind: kind,
      title: _titleForKind(kind, isContextual: isContextual),
      lastPreservedAt: now,
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: kind == WorkspaceEvidenceKind.note
          ? 'Observed the interaction at the entrance.\n'
              'Timestamp aligns with prior evidence.'
          : null,
      fileName: kind == WorkspaceEvidenceKind.attachment
          ? 'incident_report_draft.pdf'
          : null,
      isContextual: isContextual,
    );
  }

  static WorkspaceEvidenceItem createContextTextNote({
    required String parentEvidenceId,
    required String text,
  }) {
    final now = DateTime.now();
    return WorkspaceEvidenceItem(
      id: nextEvidenceId(),
      kind: WorkspaceEvidenceKind.note,
      title: 'Context — Written Note',
      lastPreservedAt: now,
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: text.trim(),
      parentEvidenceId: parentEvidenceId,
      relationshipType: RelationshipType.supports,
      isContextual: true,
      relatedEvidenceIds: {parentEvidenceId},
    );
  }

  static String _titleForKind(
    WorkspaceEvidenceKind kind, {
    required bool isContextual,
  }) {
    final prefix = isContextual ? 'Context — ' : '';
    return switch (kind) {
      WorkspaceEvidenceKind.image => '${prefix}Photo Evidence',
      WorkspaceEvidenceKind.video => '${prefix}Video Evidence',
      WorkspaceEvidenceKind.voice => '${prefix}Voice Note',
      WorkspaceEvidenceKind.note => '${prefix}Written Note',
      WorkspaceEvidenceKind.attachment => '${prefix}Attachment',
      WorkspaceEvidenceKind.witness => '${prefix}Witness Record',
    };
  }

  /// Enables deterministic IDs for tests. Production always uses UUIDs.
  static void resetForTests() {
    _testCounter = 0;
    _useDeterministicTestIds = true;
  }

  /// Restores production UUID generation after tests.
  static void useProductionIds() {
    _useDeterministicTestIds = false;
    _testCounter = 0;
  }
}
