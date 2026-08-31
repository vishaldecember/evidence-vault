import 'dart:math' as math;

import '../../domain/collection/evidence_collection.dart';
import 'collection_suggestion_provider.dart';

/// Metadata-only heuristic grouping — no AI (Sprint 5B).
///
/// Buckets by capture type, then splits dense GPS / session clusters when useful.
class HeuristicCollectionProvider implements CollectionSuggestionProvider {
  static const Duration _sessionGap = Duration(minutes: 45);
  static const double _gpsClusterMeters = 120;

  @override
  List<EvidenceCollection> suggest({
    required String incidentId,
    required List<CollectionEvidenceSignal> signals,
  }) {
    if (signals.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final buckets = <String, List<CollectionEvidenceSignal>>{};
    for (final signal in signals) {
      final key = _bucketKey(signal);
      buckets.putIfAbsent(key, () => []).add(signal);
    }

    final collections = <EvidenceCollection>[];
    var order = 0;

    for (final entry in _orderedBuckets(buckets.keys)) {
      final members = List<CollectionEvidenceSignal>.from(buckets[entry]!)
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

      final clusters = _splitClusters(members);
      if (clusters.length == 1) {
        collections.add(
          EvidenceCollection(
            id: 'col_${incidentId}_$entry',
            incidentId: incidentId,
            name: _displayName(entry),
            systemGenerated: true,
            pending: true,
            displayOrder: order++,
            createdAt: now,
            updatedAt: now,
            memberEvidenceIds: [
              for (final s in clusters.single) s.evidenceId,
            ],
          ),
        );
        continue;
      }

      for (var i = 0; i < clusters.length; i++) {
        collections.add(
          EvidenceCollection(
            id: 'col_${incidentId}_${entry}_$i',
            incidentId: incidentId,
            name: '${_displayName(entry)} ${i + 1}',
            systemGenerated: true,
            pending: true,
            displayOrder: order++,
            createdAt: now,
            updatedAt: now,
            memberEvidenceIds: [
              for (final s in clusters[i]) s.evidenceId,
            ],
          ),
        );
      }
    }

    return collections;
  }

  static String _bucketKey(CollectionEvidenceSignal signal) {
    switch (signal.kindLabel) {
      case 'photo':
      case 'video':
      case 'image':
        return 'media';
      case 'voice':
        return 'voice';
      case 'attachment':
      case 'file':
      case 'pdf':
      case 'document':
      case 'witnessStatement':
        return 'documents';
      case 'note':
        return 'notes';
      default:
        return 'other';
    }
  }

  static String _displayName(String bucket) => switch (bucket) {
        'media' => 'Media',
        'voice' => 'Voice Notes',
        'documents' => 'Documents',
        'notes' => 'Notes',
        _ => 'Other',
      };

  static List<String> _orderedBuckets(Iterable<String> keys) {
    const order = ['media', 'documents', 'voice', 'notes', 'other'];
    final set = keys.toSet();
    return [
      for (final key in order)
        if (set.contains(key)) key,
    ];
  }

  static List<List<CollectionEvidenceSignal>> _splitClusters(
    List<CollectionEvidenceSignal> ordered,
  ) {
    if (ordered.length <= 1) {
      return [ordered];
    }

    final sessions = <List<CollectionEvidenceSignal>>[];
    var current = <CollectionEvidenceSignal>[ordered.first];
    for (var i = 1; i < ordered.length; i++) {
      final prev = ordered[i - 1];
      final next = ordered[i];
      if (next.capturedAt.difference(prev.capturedAt) > _sessionGap) {
        sessions.add(current);
        current = [next];
      } else {
        current.add(next);
      }
    }
    sessions.add(current);

    final refined = <List<CollectionEvidenceSignal>>[];
    for (final session in sessions) {
      refined.addAll(_splitByGps(session));
    }
    return refined;
  }

  static List<List<CollectionEvidenceSignal>> _splitByGps(
    List<CollectionEvidenceSignal> session,
  ) {
    final withGps = session
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
    if (withGps.length < 2 || withGps.length < session.length) {
      return [session];
    }

    final clusters = <List<CollectionEvidenceSignal>>[];
    final remaining = List<CollectionEvidenceSignal>.from(session);

    while (remaining.isNotEmpty) {
      final seed = remaining.removeAt(0);
      final cluster = <CollectionEvidenceSignal>[seed];
      if (seed.latitude == null || seed.longitude == null) {
        clusters.add(cluster);
        continue;
      }
      remaining.removeWhere((candidate) {
        if (candidate.latitude == null || candidate.longitude == null) {
          return false;
        }
        final meters = _haversineMeters(
          seed.latitude!,
          seed.longitude!,
          candidate.latitude!,
          candidate.longitude!,
        );
        if (meters <= _gpsClusterMeters) {
          cluster.add(candidate);
          return true;
        }
        return false;
      });
      clusters.add(cluster);
    }

    if (clusters.length == 1) {
      return [session];
    }
    return clusters;
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

  static double _rad(double deg) => deg * math.pi / 180;
}
