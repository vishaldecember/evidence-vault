import '../../domain/collection/evidence_collection.dart';

/// Future AI providers plug in here — Sprint 5B ships heuristics only.
abstract class CollectionSuggestionProvider {
  /// Returns provisional collections for [incidentId] from [evidenceIds].
  ///
  /// Implementations must not mutate persistence; [CollectionEngine] applies.
  List<EvidenceCollection> suggest({
    required String incidentId,
    required List<CollectionEvidenceSignal> signals,
  });
}

/// Lightweight metadata signal for heuristic / future AI grouping.
class CollectionEvidenceSignal {
  const CollectionEvidenceSignal({
    required this.evidenceId,
    required this.kindLabel,
    required this.capturedAt,
    this.mimeType,
    this.latitude,
    this.longitude,
    this.deviceModel,
    this.fileName,
  });

  final String evidenceId;

  /// photo | video | voice | note | attachment | other
  final String kindLabel;
  final DateTime capturedAt;
  final String? mimeType;
  final double? latitude;
  final double? longitude;
  final String? deviceModel;
  final String? fileName;
}
