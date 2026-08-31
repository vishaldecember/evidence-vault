import '../presentation/evidence_inspector_semantics.dart';
import '../utils/workspace_evidence_formatters.dart';
import 'evidence_record_model.dart';

/// One read-only row in the [TrustSummarySection].
class TrustSummaryEntry {
  const TrustSummaryEntry({
    required this.iconName,
    required this.label,
    required this.value,
  });

  /// Material icon identifier resolved in the widget layer.
  final String iconName;
  final String label;
  final String value;
}

/// Honest integrity presentation for the Complete Record.
///
/// Does not claim hash verification, metadata verification, or event truth.
/// Hash is shown only when the domain already stored one.
class TrustSummaryModel {
  const TrustSummaryModel({required this.entries});

  final List<TrustSummaryEntry> entries;

  static TrustSummaryModel fromRecord(EvidenceRecordModel record) {
    final evidence = record.evidence;
    final entries = <TrustSummaryEntry>[
      TrustSummaryEntry(
        iconName: 'integrity',
        label: 'Independent verification',
        value: EvidenceInspectorSemantics.integrityStatus(evidence),
      ),
    ];
    final verifiedAt = EvidenceInspectorSemantics.verifiedAt(evidence);
    if (verifiedAt != null) {
      entries.add(
        TrustSummaryEntry(
          iconName: 'verifiedAt',
          label: 'Verified at',
          value: WorkspaceEvidenceFormatters.inspectorTimestamp(verifiedAt),
        ),
      );
    }
    final hash = EvidenceInspectorSemantics.contentHash(evidence);
    if (hash != null) {
      entries.add(
        TrustSummaryEntry(
          iconName: 'hash',
          label: EvidenceInspectorSemantics.hashLabel,
          value: hash,
        ),
      );
    }
    return TrustSummaryModel(entries: entries);
  }
}
