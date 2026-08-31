import '../relationship/relationship_suggestion.dart';

/// Content-intelligence RELATED suggestions.
///
/// Matter may only emit [RelationshipType.relatedTo] with
/// [RelationshipSuggestionSource.ai]. It must not emit SUPPORTS, EXPLAINS,
/// witness, context, primary, or corroboration.
///
/// Production STEP 6A uses [DisabledMatterProvider] — zero suggestions.
abstract class MatterRelationshipProvider {
  List<RelationshipSuggestion> suggestRelated({
    required String incidentId,
    required List<RelationshipEvidenceSignal> captureSignals,
  });
}

/// Production Matter provider. Does not inspect files. Emits nothing.
class DisabledMatterProvider implements MatterRelationshipProvider {
  const DisabledMatterProvider();

  @override
  List<RelationshipSuggestion> suggestRelated({
    required String incidentId,
    required List<RelationshipEvidenceSignal> captureSignals,
  }) {
    return const [];
  }
}
