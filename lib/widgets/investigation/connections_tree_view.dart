import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../engines/evidence_semantics.dart';
import '../../models/evidence_relationship.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/investigation/user_connection_overlay_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/instant_codec.dart';
import 'investigation_evidence_mark.dart';

/// Structured Connections explorer — trees, not a network graph.
class ConnectionsTreeView extends StatefulWidget {
  const ConnectionsTreeView({
    super.key,
    required this.incidentId,
    required this.evidence,
    required this.relationships,
    this.collections = const [],
    this.contextAnchors = const [],
    this.onEvidenceTap,
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> evidence;
  final List<EvidenceRelationship> relationships;
  final List<EvidenceCollection> collections;
  final List<OrganizeContextAnchor> contextAnchors;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceTap;

  static const Key viewKey = Key('connections_tree_view');
  static const Key supportingSectionKey = Key(
    'connections_tree_supporting_section',
  );
  static const Key peopleSectionKey = Key('connections_tree_people_section');
  static const Key locationsSectionKey = Key(
    'connections_tree_locations_section',
  );

  static const String supportingHeader = 'Evidence & Supporting Context';
  static const String peopleHeader = 'Evidence & People';
  static const String locationsHeader = 'Evidence & Locations';

  static Color get connectorColor => AppColors.connectionMine;

  static Key nodeKey(String id) =>
    Key('investigation_connection_node_$id');

  @override
  State<ConnectionsTreeView> createState() => _ConnectionsTreeViewState();
}

class _ConnectionsTreeViewState extends State<ConnectionsTreeView> {
  @override
  void initState() {
    super.initState();
    UserConnectionOverlayStore.instance.hydrate(widget.incidentId);
  }

  @override
  void didUpdateWidget(covariant ConnectionsTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentId != widget.incidentId) {
      UserConnectionOverlayStore.instance.hydrate(widget.incidentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserConnectionOverlayStore.instance,
      builder: (context, _) {
        final presentation = ConnectionsTreeMapper.from(
          evidence: widget.evidence,
          relationships: widget.relationships,
          collections: widget.collections,
          contextAnchors: widget.contextAnchors,
        );
        final keyed = <String>{};
        return SingleChildScrollView(
          key: ConnectionsTreeView.viewKey,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _Section(
              sectionKey: ConnectionsTreeView.supportingSectionKey,
              title: ConnectionsTreeView.supportingHeader,
              child: Column(
                children: [
                  for (final group in presentation._supporting)
                    _ParentChildrenTree(
                      parent: _evidenceNode(group.parent, keyed),
                      children: [
                        for (final child in group.children)
                          _evidenceNode(child, keyed, includeTime: false),
                      ],
                    ),
                ],
              ),
            ),
            _Section(
              sectionKey: ConnectionsTreeView.peopleSectionKey,
              title: ConnectionsTreeView.peopleHeader,
              child: Column(
                children: [
                  for (final group in presentation._people)
                    _ParentChildrenTree(
                      parent: _evidenceNode(group.parent, keyed),
                      children: [
                        for (final person in group.people) _personNode(person),
                      ],
                    ),
                ],
              ),
            ),
            _Section(
              sectionKey: ConnectionsTreeView.locationsSectionKey,
              title: ConnectionsTreeView.locationsHeader,
              child: Column(
                children: [
                  for (final group in presentation._locations)
                    _ParentChildrenTree(
                      parent: _evidenceNode(group.parent, keyed),
                      children: [
                        for (final location in group.locations)
                          _locationNode(location),
                      ],
                    ),
                ],
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  Widget _evidenceNode(
    WorkspaceEvidenceItem item,
    Set<String> keyed, {
    bool includeTime = true,
  }) {
    final key = keyed.add(item.id)
        ? ConnectionsTreeView.nodeKey(item.id)
        : Key('connections_tree_dup_${item.id}_${keyed.length}');
    return _TreeNode(
      nodeKey: key,
      icon: InvestigationEvidenceMark(
        kind: item.kind,
        color: const Color(0xFFE8F1F8),
        size: 28,
      ),
      name: ConnectionsTreeMapper.evidenceName(item),
      caption: includeTime ? ConnectionsTreeMapper.evidenceTime(item) : null,
      onTap: widget.onEvidenceTap == null
          ? null
          : () => widget.onEvidenceTap!(item),
    );
  }

  Widget _personNode(_PersonLeaf person) {
    return _TreeNode(
      nodeKey: Key('connections_tree_person_${person.id}'),
      icon: _HubMark(
        icon: Icons.person_outline_rounded,
        color: const Color(0xFFD4C4A8),
      ),
      name: person.name,
    );
  }

  Widget _locationNode(_LocationLeaf location) {
    return _TreeNode(
      nodeKey: Key('connections_tree_location_${location.id}'),
      icon: _HubMark(
        icon: Icons.place_rounded,
        color: const Color(0xFFC5B8E0),
      ),
      name: location.name,
    );
  }
}

/// Presentation-only grouping of existing incident connection data.
abstract final class ConnectionsTreeMapper {
  static ConnectionsTreePresentation from({
    required List<WorkspaceEvidenceItem> evidence,
    required List<EvidenceRelationship> relationships,
    List<EvidenceCollection> collections = const [],
    List<OrganizeContextAnchor> contextAnchors = const [],
  }) {
    final supporting = <_EvidenceGroup>[];
    for (final parent in evidence) {
      final children = [
        for (final child in evidence)
          if (_isExistingSupportingContext(
            child: child,
            parent: parent,
            relationships: relationships,
            contextAnchors: contextAnchors,
          ))
            child,
      ];
      if (children.isEmpty) {
        continue;
      }
      supporting.add(_EvidenceGroup(parent: parent, children: children));
    }

    final people = <_PeopleGroup>[];
    for (final parent in evidence) {
      final leaves = _peopleFor(parent);
      if (leaves.isEmpty) {
        continue;
      }
      people.add(_PeopleGroup(parent: parent, people: leaves));
    }

    final locations = <_LocationGroup>[];
    for (final parent in evidence) {
      final leaves = _locationsFor(parent, collections);
      if (leaves.isEmpty) {
        continue;
      }
      locations.add(_LocationGroup(parent: parent, locations: leaves));
    }

    return ConnectionsTreePresentation._(
      supporting: supporting,
      people: people,
      locations: locations,
    );
  }

  static String evidenceName(WorkspaceEvidenceItem item) {
    final preview = (item.notePreview ?? '').trim();
    if (preview.isNotEmpty) {
      return preview.split('\n').first.trim();
    }
    final fileName = (item.fileName ?? '').trim();
    if (fileName.isNotEmpty && item.kind == WorkspaceEvidenceKind.attachment) {
      return fileName;
    }
    final title = item.title.trim();
    if (title.isEmpty || title == 'Evidence ${item.id}') {
      return item.kind.label;
    }
    return title;
  }

  static String evidenceTime(WorkspaceEvidenceItem item) {
    return DateFormat('h:mm a').format(InstantCodec.toLocal(item.lastPreservedAt));
  }

  static List<_PersonLeaf> _peopleFor(WorkspaceEvidenceItem item) {
    final seen = <String>{};
    final people = <_PersonLeaf>[];
    for (final person in item.relatedPeople) {
      final name = person.displayName.trim();
      if (name.isEmpty) {
        continue;
      }
      final id = person.participantId.trim().isNotEmpty
          ? person.participantId
          : 'person:${name.toLowerCase()}';
      if (!seen.add(id)) {
        continue;
      }
      people.add(_PersonLeaf(id: id, name: name));
    }
    final legacy = (item.relatedPersonName ?? '').trim();
    if (legacy.isNotEmpty && item.relatedPeople.isEmpty) {
      final id = item.participantId ?? 'person:${legacy.toLowerCase()}';
      if (seen.add(id)) {
        people.add(_PersonLeaf(id: id, name: legacy));
      }
    }
    return people;
  }

  /// Existing supporting-context attachments only. Does not invent links.
  static bool _isExistingSupportingContext({
    required WorkspaceEvidenceItem child,
    required WorkspaceEvidenceItem parent,
    required List<EvidenceRelationship> relationships,
    required List<OrganizeContextAnchor> contextAnchors,
  }) {
    if (EvidenceSemantics.structurallySupports(
      child: child,
      parentId: parent.id,
      relationships: relationships,
    )) {
      return true;
    }
    if (child.id == parent.id) {
      return false;
    }
    if (child.relatedEvidenceIds.contains(parent.id) &&
        (child.isContextual || child.isSupportingEvidence)) {
      return true;
    }
    for (final anchor in contextAnchors) {
      if (anchor.capturedEvidenceId == parent.id &&
          anchor.contextEvidenceId == child.id) {
        return true;
      }
    }
    return false;
  }

  static List<_LocationLeaf> _locationsFor(
    WorkspaceEvidenceItem item,
    List<EvidenceCollection> collections,
  ) {
    final named = <_LocationLeaf>[];
    final seen = <String>{};
    for (final collection in collections) {
      if (collection.category != 'location') {
        continue;
      }
      final name = collection.name.trim();
      if (name.isEmpty || !collection.memberEvidenceIds.contains(item.id)) {
        continue;
      }
      if (!seen.add(collection.id)) {
        continue;
      }
      named.add(_LocationLeaf(id: collection.id, name: name));
    }
    if (named.isNotEmpty) {
      return named;
    }
    final coordinates = coordinateLabel(item);
    if (coordinates == null) {
      return const [];
    }
    return [
      _LocationLeaf(id: 'gps:${item.id}', name: coordinates),
    ];
  }

  static String? coordinateLabel(WorkspaceEvidenceItem item) {
    final latitude = item.latitude;
    final longitude = item.longitude;
    if (latitude == null || longitude == null) {
      return null;
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}

class ConnectionsTreePresentation {
  const ConnectionsTreePresentation._({
    required this._supporting,
    required this._people,
    required this._locations,
  });

  final List<_EvidenceGroup> _supporting;
  final List<_PeopleGroup> _people;
  final List<_LocationGroup> _locations;

  bool get hasSupporting => _supporting.isNotEmpty;
}

class _EvidenceGroup {
  const _EvidenceGroup({required this.parent, required this.children});

  final WorkspaceEvidenceItem parent;
  final List<WorkspaceEvidenceItem> children;
}

class _PeopleGroup {
  const _PeopleGroup({required this.parent, required this.people});

  final WorkspaceEvidenceItem parent;
  final List<_PersonLeaf> people;
}

class _PersonLeaf {
  const _PersonLeaf({required this.id, required this.name});

  final String id;
  final String name;
}

class _LocationGroup {
  const _LocationGroup({required this.parent, required this.locations});

  final WorkspaceEvidenceItem parent;
  final List<_LocationLeaf> locations;
}

class _LocationLeaf {
  const _LocationLeaf({required this.id, required this.name});

  final String id;
  final String name;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.sectionKey,
    required this.title,
    required this.child,
  });

  final Key sectionKey;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.emphasisLabel.copyWith(
                      color: AppColors.onCanvas,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  const ColoredBox(
                    color: AppColors.onCanvas,
                    child: SizedBox(height: 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ParentChildrenTree extends StatelessWidget {
  const _ParentChildrenTree({
    required this.parent,
    required this.children,
  });

  final Widget parent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final color = ConnectionsTreeView.connectorColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: [
          parent,
          if (children.isNotEmpty) ...[
            ConnectionsBidirectionalConnector(color: color),
            if (children.length == 1)
              children.single
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ColoredBox(
                  color: color,
                  child: const SizedBox(height: 1, width: double.infinity),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final child in children)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConnectionsBidirectionalConnector(
                          color: color,
                          compact: true,
                        ),
                        child,
                      ],
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class ConnectionsBidirectionalConnector extends StatelessWidget {
  const ConnectionsBidirectionalConnector({
    super.key,
    this.color,
    this.compact = false,
  });

  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? ConnectionsTreeView.connectorColor;
    return CustomPaint(
      size: Size(18, compact ? 16 : 22),
      painter: _BidirectionalStemPainter(color: paintColor),
    );
  }
}

class _BidirectionalStemPainter extends CustomPainter {
  const _BidirectionalStemPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    canvas.drawLine(Offset(x, 1), Offset(x, size.height - 1), paint);
    canvas.drawLine(Offset(x, 2), Offset(x - 3.2, 7), paint);
    canvas.drawLine(Offset(x, 2), Offset(x + 3.2, 7), paint);
    canvas.drawLine(
      Offset(x, size.height - 2),
      Offset(x - 3.2, size.height - 7),
      paint,
    );
    canvas.drawLine(
      Offset(x, size.height - 2),
      Offset(x + 3.2, size.height - 7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BidirectionalStemPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.nodeKey,
    required this.icon,
    required this.name,
    this.caption,
    this.onTap,
  });

  final Key nodeKey;
  final Widget icon;
  final String name;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 4),
        SizedBox(
          width: 88,
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onCanvas,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1.15,
            ),
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onCanvasSecondary,
              fontSize: 10,
              height: 1.2,
            ),
          ),
      ],
    );
    return GestureDetector(
      key: nodeKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: content,
      ),
    );
  }
}

class _HubMark extends StatelessWidget {
  const _HubMark({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color),
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}


