import 'timeline_anchor_node.dart';
import 'workspace_evidence_item.dart';

/// Visibility filters for the Timeline Workspace.
///
/// Filtering never reorders anchors — it only hides non-matching entries.
enum TimelineWorkspaceFilter {
  all('All'),
  photos('Photos'),
  videos('Videos'),
  voice('Voice'),
  documents('Documents'),
  notes('Notes'),
  witness('Witness');

  const TimelineWorkspaceFilter(this.label);

  final String label;

  static const List<TimelineWorkspaceFilter> valuesInDisplayOrder = [
    TimelineWorkspaceFilter.all,
    TimelineWorkspaceFilter.photos,
    TimelineWorkspaceFilter.videos,
    TimelineWorkspaceFilter.voice,
    TimelineWorkspaceFilter.documents,
    TimelineWorkspaceFilter.notes,
    TimelineWorkspaceFilter.witness,
  ];

  /// Applies [filter] to [nodes] without changing anchor chronology.
  static List<TimelineAnchorNode> apply({
    required TimelineWorkspaceFilter filter,
    required List<TimelineAnchorNode> nodes,
  }) {
    if (filter == TimelineWorkspaceFilter.all) {
      return nodes;
    }

    if (_isCapturedFilter(filter)) {
      return [
        for (final node in nodes)
          if (_matchesCaptured(node.capturedItem, filter)) node,
      ];
    }

    return [
      for (final node in nodes)
        if (_matchesItem(node.capturedItem, filter))
          node
        else if (_hasMatchingSupporting(node, filter))
          TimelineAnchorNode(
            anchor: node.anchor,
            capturedItem: node.capturedItem,
            supportingItems: [
              for (final item in node.supportingItems)
                if (_matchesItem(item, filter)) item,
            ],
          ),
    ];
  }

  static bool _isCapturedFilter(TimelineWorkspaceFilter filter) =>
      filter == TimelineWorkspaceFilter.photos ||
      filter == TimelineWorkspaceFilter.videos ||
      filter == TimelineWorkspaceFilter.voice;

  static bool _matchesCaptured(
    WorkspaceEvidenceItem item,
    TimelineWorkspaceFilter filter,
  ) =>
      switch (filter) {
        TimelineWorkspaceFilter.photos =>
          item.kind == WorkspaceEvidenceKind.image,
        TimelineWorkspaceFilter.videos =>
          item.kind == WorkspaceEvidenceKind.video,
        TimelineWorkspaceFilter.voice =>
          item.kind == WorkspaceEvidenceKind.voice,
        _ => false,
      };

  static bool _matchesItem(
    WorkspaceEvidenceItem item,
    TimelineWorkspaceFilter filter,
  ) =>
      switch (filter) {
        TimelineWorkspaceFilter.documents =>
          item.kind == WorkspaceEvidenceKind.attachment,
        TimelineWorkspaceFilter.notes => item.kind == WorkspaceEvidenceKind.note,
        TimelineWorkspaceFilter.witness => _isWitnessRelated(item),
        _ => false,
      };

  static bool _isWitnessRelated(WorkspaceEvidenceItem item) {
    if (item.kind == WorkspaceEvidenceKind.witness) {
      return true;
    }
    final role = (item.relatedPersonRole ?? '').trim().toLowerCase();
    if (role == 'witness') {
      return true;
    }
    for (final person in item.relatedPeople) {
      final personRole = (person.roleName ?? '').trim().toLowerCase();
      if (personRole == 'witness') {
        return true;
      }
    }
    return false;
  }

  static bool _hasMatchingSupporting(
    TimelineAnchorNode node,
    TimelineWorkspaceFilter filter,
  ) =>
      node.supportingItems.any((item) => _matchesItem(item, filter));
}
