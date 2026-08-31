import 'dart:math' as math;

import '../../domain/matter/matter_relationship_provider.dart';
import '../../domain/relationship/relationship_suggestion.dart';
import '../../models/relationship_type.dart';
import 'heuristic_relationship_provider.dart';

/// Composes metadata TIME/SPACE RELATED with Matter RELATED.
///
/// Heuristic output is unchanged. Matter is sanitized to relatedTo + source ai
/// and kept below the metadata auto-accept threshold so it remains suggested.
class ComposedRelationshipProvider implements RelationshipSuggestionProvider {
  ComposedRelationshipProvider({
    RelationshipSuggestionProvider? metadataProvider,
    MatterRelationshipProvider? matterProvider,
  })  : _metadataProvider =
            metadataProvider ?? HeuristicRelationshipProvider(),
        _matterProvider = matterProvider ?? const DisabledMatterProvider();

  final RelationshipSuggestionProvider _metadataProvider;
  final MatterRelationshipProvider _matterProvider;

  /// Matches [HeuristicRelationshipProvider] TIME window. Do not drift.
  static const Duration _closeCaptureWindow = Duration(seconds: 90);

  /// Matches [HeuristicRelationshipProvider] SPACE radius. Do not drift.
  static const double _nearMeters = 80;

  /// Must stay below RelationshipEngine auto-accept (0.7) so Matter is not
  /// persisted as accepted merely for exceeding the metadata threshold.
  static const double suggestionOnlyConfidenceCap = 0.69;

  static const double _timeBoost = 0.07;
  static const double _spaceBoost = 0.07;

  @override
  List<RelationshipSuggestion> suggest({
    required String incidentId,
    required List<RelationshipEvidenceSignal> signals,
  }) {
    final metadata = _metadataProvider.suggest(
      incidentId: incidentId,
      signals: signals,
    );
    final matter = _sanitizeMatter(
      _matterProvider.suggestRelated(
        incidentId: incidentId,
        captureSignals: signals,
      ),
      signals,
    );
    if (matter.isEmpty) {
      return metadata;
    }
    return [...metadata, ...matter];
  }

  List<RelationshipSuggestion> _sanitizeMatter(
    List<RelationshipSuggestion> raw,
    List<RelationshipEvidenceSignal> signals,
  ) {
    final byId = {for (final signal in signals) signal.evidenceId: signal};
    final out = <RelationshipSuggestion>[];
    final seen = <String>{};

    for (final suggestion in raw) {
      if (suggestion.relationshipType != RelationshipType.relatedTo.name) {
        continue;
      }
      final reason = suggestion.reason.trim();
      if (reason.isEmpty || _hasForbiddenClaim(reason)) {
        continue;
      }
      final a = byId[suggestion.sourceEvidenceId];
      final b = byId[suggestion.targetEvidenceId];
      if (a != null && b != null && _isParentChild(a, b)) {
        continue;
      }

      final key = _pairKey(
        suggestion.sourceEvidenceId,
        suggestion.targetEvidenceId,
      );
      if (!seen.add(key)) {
        continue;
      }

      final timeExplanation = _timeExplanation(a, b);
      final spaceExplanation = _spaceExplanation(a, b);
      final matterExplanation = (suggestion.matterExplanation ?? '').trim().isEmpty
          ? _matterClauseFrom(reason)
          : suggestion.matterExplanation!.trim();
      if (matterExplanation == null ||
          matterExplanation.isEmpty ||
          _hasForbiddenClaim(matterExplanation)) {
        continue;
      }

      var confidence = suggestion.confidence;
      if (timeExplanation != null) {
        confidence += _timeBoost;
      }
      if (spaceExplanation != null) {
        confidence += _spaceBoost;
      }
      if (confidence > suggestionOnlyConfidenceCap) {
        confidence = suggestionOnlyConfidenceCap;
      }

      out.add(
        RelationshipSuggestion(
          id: suggestion.id,
          incidentId: suggestion.incidentId,
          sourceEvidenceId: suggestion.sourceEvidenceId,
          targetEvidenceId: suggestion.targetEvidenceId,
          relationshipType: RelationshipType.relatedTo.name,
          confidence: confidence,
          reason: _composedReason(
            matterExplanation: matterExplanation,
            timeExplanation: timeExplanation,
            spaceExplanation: spaceExplanation,
          ),
          source: RelationshipSuggestionSource.ai,
          status: RelationshipSuggestionStatus.suggested,
          createdAt: suggestion.createdAt,
          timeExplanation: timeExplanation,
          spaceExplanation: spaceExplanation,
          matterExplanation: matterExplanation,
        ),
      );
    }
    return out;
  }

  static String _composedReason({
    required String matterExplanation,
    String? timeExplanation,
    String? spaceExplanation,
  }) {
    final extras = <String>[
      if (timeExplanation != null) _asBecauseClause(timeExplanation),
      if (spaceExplanation != null) _asBecauseClause(spaceExplanation),
    ];
    if (extras.isEmpty) {
      return 'Suggested relationship because $matterExplanation.';
    }
    return 'Suggested relationship because $matterExplanation, '
        '${extras.join(', and ')}.';
  }

  static String _asBecauseClause(String explanation) {
    var clause = explanation.trim();
    if (clause.endsWith('.')) {
      clause = clause.substring(0, clause.length - 1);
    }
    if (clause.isEmpty) {
      return clause;
    }
    return clause[0].toLowerCase() + clause.substring(1);
  }

  static String? _timeExplanation(
    RelationshipEvidenceSignal? a,
    RelationshipEvidenceSignal? b,
  ) {
    if (a == null || b == null) {
      return null;
    }
    final delta = a.capturedAt.difference(b.capturedAt).abs();
    if (delta.inSeconds <= 0 || delta > _closeCaptureWindow) {
      return null;
    }
    return 'Captured ${delta.inSeconds} seconds apart';
  }

  static String? _spaceExplanation(
    RelationshipEvidenceSignal? a,
    RelationshipEvidenceSignal? b,
  ) {
    if (a == null || b == null) {
      return null;
    }
    if (a.latitude == null ||
        a.longitude == null ||
        b.latitude == null ||
        b.longitude == null) {
      return null;
    }
    final meters = _haversineMeters(
      a.latitude!,
      a.longitude!,
      b.latitude!,
      b.longitude!,
    );
    if (meters > _nearMeters) {
      return null;
    }
    final rounded = meters.round();
    if (rounded <= 0) {
      return 'Captured at the same location';
    }
    return 'Captured $rounded metres apart';
  }

  static bool _hasForbiddenClaim(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('corroborat') ||
        lower.contains('ai detected') ||
        lower.contains('ai believes') ||
        lower.contains('likely proves') ||
        lower.contains('same event') ||
        lower.contains('confirms') ||
        lower.contains('proves')) {
      return true;
    }
    return RegExp(r'\bsupports\b').hasMatch(lower);
  }

  static String? _matterClauseFrom(String reason) {
    const prefix = 'Suggested relationship because ';
    var clause = reason.trim();
    if (clause.startsWith(prefix)) {
      clause = clause.substring(prefix.length);
    } else if (clause.startsWith('Related because ')) {
      clause = clause.substring('Related because '.length);
    }
    if (clause.endsWith('.')) {
      clause = clause.substring(0, clause.length - 1);
    }
    clause = clause.trim();
    return clause.isEmpty ? null : clause;
  }

  static bool _isParentChild(
    RelationshipEvidenceSignal a,
    RelationshipEvidenceSignal b,
  ) {
    return a.parentEvidenceId == b.evidenceId ||
        b.parentEvidenceId == a.evidenceId;
  }

  static String _pairKey(String a, String b) {
    if (a.compareTo(b) <= 0) {
      return '${a}__$b';
    }
    return '${b}__$a';
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earth * c;
  }

  static double _rad(double d) => d * math.pi / 180;
}
