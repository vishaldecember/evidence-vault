import '../services/relationship_group_color_service.dart';
import 'relationship_group.dart';

/// Pure UI state for Workspace Connect Mode — never persisted.
///
/// Selections accumulate here until the user presses Done. No repository,
/// relationship engine, or confirmation feedback runs during selection.
class TemporaryRelationshipGroup {
  const TemporaryRelationshipGroup({
    this.evidenceIds = const {},
    this.colorIndex = 0,
  });

  final Set<String> evidenceIds;
  final int colorIndex;

  bool get isEmpty => evidenceIds.isEmpty;

  /// At least two artifacts are required to commit a [RelationshipGroup].
  bool get canCommit => evidenceIds.length >= 2;

  factory TemporaryRelationshipGroup.initial(
    List<RelationshipGroup> committedGroups,
  ) {
    return TemporaryRelationshipGroup(
      colorIndex: RelationshipGroupColorService.nextColorIndex(committedGroups),
    );
  }

  bool isSelected(String evidenceId) => evidenceIds.contains(evidenceId);

  TemporaryRelationshipGroup toggle(String evidenceId) {
    final next = Set<String>.from(evidenceIds);
    if (next.contains(evidenceId)) {
      next.remove(evidenceId);
    } else {
      next.add(evidenceId);
    }
    return TemporaryRelationshipGroup(
      evidenceIds: next,
      colorIndex: colorIndex,
    );
  }

  TemporaryRelationshipGroup clear() =>
      TemporaryRelationshipGroup(colorIndex: colorIndex);
}
