import '../../models/timeline_anchor_node.dart';
import '../../utils/workspace_evidence_formatters.dart';
import 'timeline_evidence_labels.dart';

/// Investigative metadata shown on Timeline Anchor cards only.
///
/// Chronology:
/// - **Order** is capture chronology ([TimelineAnchor.sequenceOrder]).
/// - **Clock** is [WorkspaceEvidenceFormatters.evidenceClock] of the evidence
///   instant ([WorkspaceEvidenceItem.lastPreservedAt]), matching Inspector.
///
/// Device and location are shown only when recorded on the evidence.
class TimelineAnchorCardMetadata {
  const TimelineAnchorCardMetadata({
    required this.captureTime,
    required this.evidenceTypeLabel,
    required this.capturedEmoji,
    this.deviceName,
    this.captureLocation,
  });

  final String captureTime;
  final String evidenceTypeLabel;
  final String capturedEmoji;
  final String? deviceName;
  final String? captureLocation;

  factory TimelineAnchorCardMetadata.fromNode(TimelineAnchorNode node) {
    final item = node.capturedItem;
    return TimelineAnchorCardMetadata(
      captureTime: WorkspaceEvidenceFormatters.evidenceClock(
        item.lastPreservedAt,
      ),
      evidenceTypeLabel: item.kind.label,
      capturedEmoji: TimelineEvidenceLabels.capturedEmoji(item.kind),
      deviceName: _displayDevice(item.deviceModel),
      captureLocation: _displayLocation(
        latitude: item.latitude,
        longitude: item.longitude,
      ),
    );
  }

  static String? _displayDevice(String? device) {
    final trimmed = device?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? _displayLocation({
    double? latitude,
    double? longitude,
  }) {
    if (latitude == null || longitude == null) {
      return null;
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
