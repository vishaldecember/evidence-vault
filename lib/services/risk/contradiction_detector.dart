import 'dart:math' as math;

import '../../domain/evidence/captured_evidence.dart';

/// Simple deterministic contradiction signals (Sprint 5E).
///
/// No semantic / NLP contradiction detection.
class ContradictionHit {
  const ContradictionHit({
    required this.evidenceIds,
    required this.reason,
    required this.sourceLabel,
  });

  final List<String> evidenceIds;
  final String reason;
  final String sourceLabel;
}

abstract final class ContradictionDetector {
  ContradictionDetector._();

  /// Two captures within [window] but GPS distance > [minMeters].
  static List<ContradictionHit> geoTimestampConflicts({
    required List<CapturedEvidence> captured,
    Duration window = const Duration(seconds: 60),
    double minMeters = 500,
  }) {
    final withGeo = [
      for (final item in captured)
        if (item.latitude != null && item.longitude != null) item,
    ];
    if (withGeo.length < 2) {
      return const [];
    }

    final hits = <ContradictionHit>[];
    for (var i = 0; i < withGeo.length; i++) {
      for (var j = i + 1; j < withGeo.length; j++) {
        final a = withGeo[i];
        final b = withGeo[j];
        final delta = a.capturedAt.difference(b.capturedAt).abs();
        if (delta > window) {
          continue;
        }
        final meters = _haversineMeters(
          a.latitude!,
          a.longitude!,
          b.latitude!,
          b.longitude!,
        );
        if (meters < minMeters) {
          continue;
        }
        hits.add(
          ContradictionHit(
            evidenceIds: [a.id, b.id],
            reason:
                'Two evidence items were captured within ${delta.inSeconds}s '
                'but GPS places are about ${meters.round()}m apart.',
            sourceLabel: '${a.title} · ${b.title}',
          ),
        );
      }
    }
    return hits;
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
