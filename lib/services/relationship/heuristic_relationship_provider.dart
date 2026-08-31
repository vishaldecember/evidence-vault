import 'dart:math' as math;

import '../../domain/relationship/relationship_suggestion.dart';
import '../../models/relationship_type.dart';

/// Metadata-only RELATED suggestions — never invents SUPPORTS claims (Sprint 5C).
class HeuristicRelationshipProvider implements RelationshipSuggestionProvider {
  static const Duration _closeCaptureWindow = Duration(seconds: 90);
  static const double _nearMeters = 80;

  @override
  List<RelationshipSuggestion> suggest({
    required String incidentId,
    required List<RelationshipEvidenceSignal> signals,
  }) {
    if (signals.length < 2) {
      return const [];
    }

    final ordered = List<RelationshipEvidenceSignal>.from(signals)
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final now = DateTime.now();
    final out = <RelationshipSuggestion>[];
    final seen = <String>{};

    void addPair(
      RelationshipEvidenceSignal a,
      RelationshipEvidenceSignal b,
      String reason,
      double confidence,
    ) {
      final key = _pairKey(a.evidenceId, b.evidenceId);
      if (!seen.add(key)) {
        return;
      }
      out.add(
        RelationshipSuggestion(
          id: 'rel_sug_${incidentId}_$key',
          incidentId: incidentId,
          sourceEvidenceId: a.evidenceId,
          targetEvidenceId: b.evidenceId,
          relationshipType: RelationshipType.relatedTo.name,
          confidence: confidence,
          reason: reason,
          source: RelationshipSuggestionSource.metadata,
          status: RelationshipSuggestionStatus.suggested,
          createdAt: now,
        ),
      );
    }

    final byCollection = <String, List<RelationshipEvidenceSignal>>{};
    for (final s in ordered) {
      final cid = s.collectionId;
      if (cid == null || cid.isEmpty) {
        continue;
      }
      byCollection.putIfAbsent(cid, () => []).add(s);
    }
    for (final entry in byCollection.entries) {
      final members = entry.value;
      if (members.length < 2) {
        continue;
      }
      final name = members.first.collectionName?.trim();
      final label =
          (name != null && name.isNotEmpty) ? name : 'the same collection';
      for (var i = 0; i < members.length; i++) {
        for (var j = i + 1; j < members.length; j++) {
          addPair(
            members[i],
            members[j],
            'Related through $label.',
            0.72,
          );
        }
      }
    }

    for (var i = 0; i < ordered.length; i++) {
      for (var j = i + 1; j < ordered.length; j++) {
        final a = ordered[i];
        final b = ordered[j];
        final delta = b.capturedAt.difference(a.capturedAt);
        if (delta > _closeCaptureWindow) {
          break;
        }
        if (delta.inSeconds <= 0) {
          continue;
        }
        addPair(
          a,
          b,
          'Related because these were captured ${delta.inSeconds} seconds apart.',
          0.8,
        );
      }
    }

    for (var i = 0; i < ordered.length; i++) {
      final a = ordered[i];
      if (a.latitude == null || a.longitude == null) {
        continue;
      }
      for (var j = i + 1; j < ordered.length; j++) {
        final b = ordered[j];
        if (b.latitude == null || b.longitude == null) {
          continue;
        }
        final meters = _haversineMeters(
          a.latitude!,
          a.longitude!,
          b.latitude!,
          b.longitude!,
        );
        if (meters <= _nearMeters) {
          addPair(
            a,
            b,
            'Related because these were captured near the same location.',
            0.75,
          );
        }
      }
    }

    return [
      for (final s in out)
        if (!_isParentChild(s, signals)) s,
    ];
  }

  static bool _isParentChild(
    RelationshipSuggestion suggestion,
    List<RelationshipEvidenceSignal> signals,
  ) {
    final byId = {for (final s in signals) s.evidenceId: s};
    final a = byId[suggestion.sourceEvidenceId];
    final b = byId[suggestion.targetEvidenceId];
    if (a == null || b == null) {
      return false;
    }
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
