import '../../domain/matter/matter_content_signal.dart';
import '../../domain/matter/matter_relationship_provider.dart';
import '../../domain/relationship/relationship_suggestion.dart';
import '../../models/relationship_type.dart';

/// Maps caller-supplied [MatterContentSignal]s into RELATED suggestions.
///
/// This is not an AI extractor. It does not read pixels, audio, or documents.
/// It only emits a suggestion when explicit **specific** content facts overlap.
/// Generic tokens such as "car" or "incident" never produce RELATED.
class ExplicitMatterRelationshipProvider implements MatterRelationshipProvider {
  const ExplicitMatterRelationshipProvider({
    this.contentSignals = const [],
  });

  final List<MatterContentSignal> contentSignals;

  /// Matter-only RELATED stays below metadata auto-accept (0.7).
  static const double matterOnlyConfidence = 0.55;

  /// STEP 6B false-positive control — overlap of these tokens is not Matter.
  static const Set<String> genericTokens = {
    'and',
    'audio',
    'black',
    'blue',
    'building',
    'car',
    'city',
    'content',
    'country',
    'document',
    'event',
    'evidence',
    'file',
    'gray',
    'green',
    'grey',
    'image',
    'incident',
    'item',
    'location',
    'note',
    'object',
    'person',
    'phone',
    'photo',
    'place',
    'red',
    'sign',
    'similar',
    'street',
    'the',
    'town',
    'tree',
    'vehicle',
    'video',
    'white',
    'yellow',
  };

  @override
  List<RelationshipSuggestion> suggestRelated({
    required String incidentId,
    required List<RelationshipEvidenceSignal> captureSignals,
  }) {
    if (contentSignals.length < 2) {
      return const [];
    }
    final now = DateTime.now();
    final out = <RelationshipSuggestion>[];
    final seen = <String>{};

    for (var i = 0; i < contentSignals.length; i++) {
      for (var j = i + 1; j < contentSignals.length; j++) {
        final a = contentSignals[i];
        final b = contentSignals[j];
        if (a.evidenceId == b.evidenceId) {
          continue;
        }
        final match = _match(a, b);
        if (match == null) {
          continue;
        }
        final key = _pairKey(a.evidenceId, b.evidenceId);
        if (!seen.add(key)) {
          continue;
        }
        out.add(
          RelationshipSuggestion(
            id: 'rel_sug_matter_${incidentId}_$key',
            incidentId: incidentId,
            sourceEvidenceId: a.evidenceId,
            targetEvidenceId: b.evidenceId,
            relationshipType: RelationshipType.relatedTo.name,
            confidence: matterOnlyConfidence,
            reason: 'Suggested relationship because ${match.clause}.',
            source: RelationshipSuggestionSource.ai,
            status: RelationshipSuggestionStatus.suggested,
            createdAt: now,
            matterExplanation: match.clause,
          ),
        );
      }
    }
    return out;
  }

  static _MatterMatch? _match(MatterContentSignal a, MatterContentSignal b) {
    final sharedPlaces = _intersection(a.placeMentions, b.placeMentions);
    if (sharedPlaces.isNotEmpty) {
      return _MatterMatch(
        _referenceClause(sharedPlaces, a.placeMentions, b.placeMentions),
      );
    }
    final sharedEntities = _intersection(a.namedEntities, b.namedEntities);
    if (sharedEntities.isNotEmpty) {
      return _MatterMatch(
        _referenceClause(sharedEntities, a.namedEntities, b.namedEntities),
      );
    }
    final sharedObjects = _intersection(a.objectLabels, b.objectLabels);
    if (sharedObjects.isNotEmpty) {
      return _MatterMatch(
        _referenceClause(sharedObjects, a.objectLabels, b.objectLabels),
      );
    }
    final sharedTopics = _intersection(a.topics, b.topics);
    if (sharedTopics.isNotEmpty) {
      return _MatterMatch(
        _referenceClause(sharedTopics, a.topics, b.topics),
      );
    }
    final sameGroup = _normalized(a.similarityGroupId) != null &&
        _normalized(a.similarityGroupId) == _normalized(b.similarityGroupId);
    if (sameGroup) {
      return const _MatterMatch('both records reference similar content');
    }
    return null;
  }

  static String _referenceClause(
    Set<String> shared,
    List<String> originalsA,
    List<String> originalsB,
  ) {
    return 'both records reference ${_displayFact(shared, originalsA, originalsB)}';
  }

  static String _displayFact(
    Set<String> shared,
    List<String> originalsA,
    List<String> originalsB,
  ) {
    for (final value in [...originalsA, ...originalsB]) {
      final normalized = _normalized(value);
      if (normalized != null && shared.contains(normalized)) {
        return value.trim();
      }
    }
    return shared.first;
  }

  static Set<String> _intersection(List<String> a, List<String> b) {
    final left = {
      for (final value in a)
        if (_isSpecific(_normalized(value))) _normalized(value)!,
    };
    final right = {
      for (final value in b)
        if (_isSpecific(_normalized(value))) _normalized(value)!,
    };
    return left.intersection(right);
  }

  static bool _isSpecific(String? token) {
    if (token == null || token.length < 3) {
      return false;
    }
    if (genericTokens.contains(token) ||
        _looksLikeFilename(token) ||
        _looksLikeGps(token)) {
      return false;
    }
    return true;
  }

  /// Camera / export names are not content facts. Do not parse `Honda` out of
  /// `IMG_20260815_Honda.jpg`.
  static final RegExp _filenameExtension = RegExp(
    r'\.(jpe?g|png|gif|webp|heic|heif|mp4|mov|m4a|aac|wav|pdf|docx?|txt|csv)$',
  );

  static bool _looksLikeFilename(String token) {
    return _filenameExtension.hasMatch(token) || token.startsWith('img_');
  }

  /// Capture coordinates are SPACE metadata, not Matter place mentions.
  static final RegExp _coordinateToken = RegExp(r'^-?\d{1,3}(\.\d+)?$');
  static final RegExp _latLonPair = RegExp(
    r'^-?\d{1,3}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?$',
  );

  static bool _looksLikeGps(String token) {
    return _coordinateToken.hasMatch(token) || _latLonPair.hasMatch(token);
  }

  static String? _normalized(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String _pairKey(String a, String b) {
    if (a.compareTo(b) <= 0) {
      return '${a}__$b';
    }
    return '${b}__$a';
  }
}

class _MatterMatch {
  const _MatterMatch(this.clause);

  final String clause;
}
