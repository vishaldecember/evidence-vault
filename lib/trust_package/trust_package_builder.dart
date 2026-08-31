import '../models/evidence_relationship.dart';
import '../models/reflection_model.dart';
import '../models/trust_package_model.dart';
import '../models/verification_factory.dart';
import '../models/workspace_evidence_item.dart';
import '../story/story_builder.dart';

/// Input snapshot for trust package assembly — reads existing domain data only.
class TrustPackageBuildContext {
  const TrustPackageBuildContext({
    required this.items,
    required this.relationships,
    required this.reflections,
  });

  final List<WorkspaceEvidenceItem> items;
  final List<EvidenceRelationship> relationships;
  final List<ReflectionModel> reflections;
}

/// Assembles a [TrustPackageModel] from preserved incident information.
///
/// Deterministic. Never changes evidence. Future exports (PDF, court,
/// insurance, legal, archive) should reuse this presentation model.
abstract class TrustPackageBuilder {
  TrustPackageModel build(TrustPackageBuildContext context);
}

/// Default deterministic trust package assembly from workspace state.
class DefaultTrustPackageBuilder implements TrustPackageBuilder {
  const DefaultTrustPackageBuilder({StoryBuilder? storyBuilder})
      : _storyBuilder = storyBuilder ?? const DefaultStoryBuilder();

  final StoryBuilder _storyBuilder;

  static const _integrityExplanation =
      'This package represents preserved information assembled from the '
      'current incident.';

  @override
  TrustPackageModel build(TrustPackageBuildContext context) {
    final story = _storyBuilder.build(
      StoryBuildContext(
        items: context.items,
        relationships: context.relationships,
        reflections: context.reflections,
      ),
    );

    final artifacts = context.items
        .where((item) => !item.isContextual)
        .toList()
      ..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));

    final integrityVerified = artifacts.isNotEmpty &&
        artifacts.every((artifact) => artifact.integrityVerified);

    return TrustPackageModel(
      incidentSummary: story.summary,
      story: story,
      timeline: story.timeline,
      evidence: artifacts,
      context: story.supportingContext,
      linkedEvidence: story.linkedEvidence,
      reflections: story.reflections,
      integrityVerified: integrityVerified,
      integrityExplanation: _integrityExplanation,
      verification: VerificationFactory.forArtifacts(context.items),
    );
  }
}
