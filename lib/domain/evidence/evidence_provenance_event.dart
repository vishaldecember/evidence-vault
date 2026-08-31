import 'dart:convert';

import '../../utils/instant_codec.dart';

/// Append-only evidence lifecycle event. Historical rows are never rewritten.
enum EvidenceProvenanceType {
  captured,
  preserved,
  contextAdded;

  static EvidenceProvenanceType? fromWire(String? raw) {
    final name = raw?.trim() ?? '';
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}

class EvidenceProvenanceEvent {
  const EvidenceProvenanceEvent({
    required this.type,
    required this.evidenceId,
    required this.at,
    this.captureModality,
    this.source,
    this.contentHash,
    this.storageReference,
  });

  /// Local-cache metadata key. Not a second evidence store.
  static const metadataKey = 'ev_provenance_v1';

  final EvidenceProvenanceType type;
  final String evidenceId;
  final DateTime at;
  final String? captureModality;
  final String? source;
  final String? contentHash;
  final String? storageReference;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'evidenceId': evidenceId,
      'at': InstantCodec.encode(at),
      if (captureModality != null && captureModality!.trim().isNotEmpty)
        'captureModality': captureModality,
      if (source != null && source!.trim().isNotEmpty) 'source': source,
      if (contentHash != null && contentHash!.trim().isNotEmpty)
        'contentHash': contentHash,
      if (storageReference != null && storageReference!.trim().isNotEmpty)
        'storageReference': storageReference,
    };
  }

  static EvidenceProvenanceEvent? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final type = EvidenceProvenanceType.fromWire(map['type'] as String?);
    final evidenceId = (map['evidenceId'] as String?)?.trim() ?? '';
    final at = InstantCodec.decode(map['at']);
    if (type == null || evidenceId.isEmpty || at == null) {
      return null;
    }
    return EvidenceProvenanceEvent(
      type: type,
      evidenceId: evidenceId,
      at: at,
      captureModality: (map['captureModality'] as String?)?.trim(),
      source: (map['source'] as String?)?.trim(),
      contentHash: (map['contentHash'] as String?)?.trim(),
      storageReference: (map['storageReference'] as String?)?.trim(),
    );
  }

  /// Appends [next] without mutating [existing] rows.
  ///
  /// CAPTURED / PRESERVED are recorded once. Later calls do not replace them.
  static List<EvidenceProvenanceEvent> append({
    required List<EvidenceProvenanceEvent> existing,
    required EvidenceProvenanceEvent next,
  }) {
    if (next.type == EvidenceProvenanceType.captured ||
        next.type == EvidenceProvenanceType.preserved) {
      if (existing.any((event) => event.type == next.type)) {
        return List<EvidenceProvenanceEvent>.from(existing);
      }
    }
    return [...existing, next];
  }

  static List<EvidenceProvenanceEvent> fromJsonList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw) ?fromJson(item),
    ];
  }

  static List<EvidenceProvenanceEvent> fromMetadata(
    Map<String, String> metadata,
  ) {
    final raw = metadata[metadataKey];
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      return fromJsonList(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String> toMetadata(
    List<EvidenceProvenanceEvent> events, {
    Map<String, String> existing = const {},
  }) {
    final next = Map<String, String>.from(existing);
    if (events.isEmpty) {
      next.remove(metadataKey);
      return next;
    }
    next[metadataKey] = jsonEncode([for (final event in events) event.toJson()]);
    return next;
  }
}
