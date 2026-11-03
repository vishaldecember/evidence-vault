import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/investigation/connection_trace.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/domain/participant/related_person_link.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/investigation/user_connection_overlay_store.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/investigation/connections_tree_view.dart';
import 'package:evidence_vault/widgets/investigation/investigation_graph_workspace.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String title = '',
  DateTime? lastPreservedAt,
  String? parentEvidenceId,
  List<RelatedPersonLink> relatedPeople = const [],
  String? relatedPersonName,
  bool isContextual = false,
  Set<String> relatedEvidenceIds = const {},
  String? notePreview,
  String? fileName,
  double? latitude,
  double? longitude,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: title.isEmpty ? 'Evidence $id' : title,
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 8, 14, 10, 42),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    relatedPeople: relatedPeople,
    relatedPersonName: relatedPersonName,
    isContextual: isContextual,
    relatedEvidenceIds: relatedEvidenceIds,
    notePreview: notePreview,
    fileName: fileName,
    latitude: latitude,
    longitude: longitude,
  );
}

Future<void> _pumpTree(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceRelationship> relationships = const [],
  List<EvidenceCollection> collections = const [],
  List<OrganizeContextAnchor> contextAnchors = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConnectionsTreeView(
          incidentId: 'inc-A',
          evidence: evidence,
          relationships: relationships,
          collections: collections,
          contextAnchors: contextAnchors,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserConnectionOverlayStore.instance.resetForTests();
  });

  testWidgets('Connections tree renders the three structured sections', (
    tester,
  ) async {
    final photo = _item(
      id: 'photo',
      title: 'Street Fighter',
      relatedPeople: const [
        RelatedPersonLink(
          participantId: 'p-john',
          displayName: 'John',
        ),
      ],
    );
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      title: 'Threat',
      parentEvidenceId: 'photo',
      isContextual: true,
    );
    await _pumpTree(
      tester,
      evidence: [photo, note],
      relationships: [
        EvidenceRelationship(
          id: 'rel-1',
          sourceEvidenceId: 'photo',
          targetEvidenceId: 'note',
          type: RelationshipType.supports,
          createdAt: DateTime(2026, 8, 14),
          source: 'user',
        ),
      ],
      collections: [
        EvidenceCollection(
          id: 'loc-1',
          incidentId: 'inc-A',
          name: 'Lobby',
          category: 'location',
          systemGenerated: true,
          displayOrder: 0,
          createdAt: DateTime(2026, 8, 14),
          updatedAt: DateTime(2026, 8, 14),
          memberEvidenceIds: const ['photo'],
        ),
      ],
    );

    expect(find.byType(ConnectionsTreeView), findsOneWidget);
    expect(find.text('Evidence & Supporting Context'), findsOneWidget);
    expect(find.text('Evidence & People'), findsOneWidget);
    expect(find.text('Evidence & Locations'), findsOneWidget);
    expect(find.text('Evidence & Relationships'), findsNothing);
    expect(find.text('My Connections'), findsNothing);
    expect(find.byType(ConnectionsBidirectionalConnector), findsWidgets);
    expect(find.byType(JourneyEvidenceThumbnail), findsNothing);
    expect(find.byKey(InvestigationGraphWorkspace.spineKey), findsNothing);
    expect(find.text('TIME'), findsNothing);

    for (final title in [
      'Evidence & Supporting Context',
      'Evidence & People',
      'Evidence & Locations',
    ]) {
      final headerFinder = find.text(title);
      final header = tester.widget<Text>(headerFinder);
      expect(header.textAlign, TextAlign.center);
      expect(header.style?.fontSize, 15);
      expect(header.style?.fontWeight, FontWeight.w700);
      expect(header.style?.decoration, isNot(TextDecoration.underline));
      final underline = find.descendant(
        of: find.ancestor(
          of: headerFinder,
          matching: find.byType(IntrinsicWidth),
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 2,
        ),
      );
      expect(underline, findsOneWidget);
    }
    expect(
      tester.widget<ConnectionsBidirectionalConnector>(
        find.byType(ConnectionsBidirectionalConnector).first,
      ).color,
      AppColors.connectionMine,
    );
  });

  testWidgets('supporting context sits under the moment, not beside a hub', (
    tester,
  ) async {
    final photo = _item(id: 'photo', title: 'Street Fighter');
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      title: 'Threat',
      parentEvidenceId: 'photo',
      isContextual: true,
    );
    await _pumpTree(tester, evidence: [photo, note]);

    final moment = tester.getRect(find.text('Street Fighter'));
    final context = tester.getRect(find.text('Threat'));
    expect(context.top, greaterThan(moment.bottom));
    expect(find.byType(ConnectionsBidirectionalConnector), findsWidgets);
  });

  testWidgets('contextual relatedEvidenceIds appear under the moment', (
    tester,
  ) async {
    final photo = _item(id: 'photo', title: 'Street Fighter');
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      title: 'Door note',
      isContextual: true,
      relatedEvidenceIds: const {'photo'},
      notePreview: 'Door',
    );
    await _pumpTree(tester, evidence: [photo, note]);

    expect(find.text('Door'), findsOneWidget);
    expect(
      tester.getRect(find.text('Door')).top,
      greaterThan(tester.getRect(find.text('Street Fighter')).bottom),
    );
  });

  testWidgets('organize context anchors appear under their moment', (
    tester,
  ) async {
    final photo = _item(id: 'photo', title: 'Street Fighter');
    final file = _item(
      id: 'file',
      kind: WorkspaceEvidenceKind.attachment,
      title: 'Context file',
      fileName: 'Document',
    );
    await _pumpTree(
      tester,
      evidence: [photo, file],
      contextAnchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'file',
          capturedEvidenceId: 'photo',
        ),
      ],
    );

    expect(find.text('Document'), findsOneWidget);
    expect(
      tester.getRect(find.text('Document')).top,
      greaterThan(tester.getRect(find.text('Street Fighter')).bottom),
    );
  });

  testWidgets('supporting context spreads horizontally under the moment', (
    tester,
  ) async {
    final photo = _item(id: 'photo', title: 'Street Fighter');
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      title: 'Threat',
      parentEvidenceId: 'photo',
      isContextual: true,
    );
    final file = _item(
      id: 'file',
      kind: WorkspaceEvidenceKind.attachment,
      title: 'Document',
      parentEvidenceId: 'photo',
      isContextual: true,
    );
    await _pumpTree(tester, evidence: [photo, note, file]);

    final moment = tester.getRect(find.text('Street Fighter'));
    final threat = tester.getRect(find.text('Threat'));
    final document = tester.getRect(find.text('Document'));
    expect(threat.top, greaterThan(moment.bottom));
    expect(document.top, greaterThan(moment.bottom));
    expect(threat.top, closeTo(document.top, 8));
    expect((threat.center.dx - document.center.dx).abs(), greaterThan(20));
  });

  testWidgets('people render as icon plus name, not a timestamp label', (
    tester,
  ) async {
    final photo = _item(
      id: 'photo',
      title: 'Street Fighter',
      relatedPeople: const [
        RelatedPersonLink(
          participantId: 'p-john',
          displayName: 'John',
        ),
      ],
    );
    await _pumpTree(tester, evidence: [photo]);

    expect(find.text('John'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(
      tester.getRect(find.text('John')).top,
      greaterThan(tester.getRect(find.text('Street Fighter')).bottom),
    );
  });

  testWidgets('locations render as icon plus place name', (tester) async {
    final photo = _item(
      id: 'photo',
      title: 'Street Fighter',
      latitude: 30.08691,
      longitude: 78.26761,
    );
    await _pumpTree(
      tester,
      evidence: [photo],
      collections: [
        EvidenceCollection(
          id: 'loc-1',
          incidentId: 'inc-A',
          name: 'Lobby',
          category: 'location',
          systemGenerated: true,
          displayOrder: 0,
          createdAt: DateTime(2026, 8, 14),
          updatedAt: DateTime(2026, 8, 14),
          memberEvidenceIds: const ['photo'],
        ),
      ],
    );

    expect(find.text('Lobby'), findsOneWidget);
    expect(find.text('30.0869, 78.2676'), findsNothing);
    expect(find.byIcon(Icons.place_rounded), findsOneWidget);
  });

  testWidgets('unnamed locations fall back to recorded coordinates', (
    tester,
  ) async {
    final photo = _item(
      id: 'photo',
      title: 'Street Fighter',
      latitude: 30.08691,
      longitude: 78.26761,
    );
    await _pumpTree(tester, evidence: [photo]);

    expect(find.text('30.0869, 78.2676'), findsOneWidget);
    expect(find.text('Coffee Shop'), findsNothing);
    expect(find.byIcon(Icons.place_rounded), findsOneWidget);
    expect(
      tester.getRect(find.text('30.0869, 78.2676')).top,
      greaterThan(tester.getRect(find.text('Street Fighter')).bottom),
    );
  });

  testWidgets('Evidence & Relationships is not rendered', (tester) async {
    final photo = _item(id: 'photo', title: 'Evidence A');
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      title: 'Evidence B',
    );
    await _pumpTree(
      tester,
      evidence: [photo, video],
      relationships: [
        EvidenceRelationship(
          id: 'rel-1',
          sourceEvidenceId: 'photo',
          targetEvidenceId: 'video',
          type: RelationshipType.supports,
          createdAt: DateTime(2026, 8, 14),
          source: 'user',
        ),
      ],
    );

    expect(find.text('Evidence & Relationships'), findsNothing);
    expect(find.text('Supports'), findsNothing);
    expect(find.text('Caused by'), findsNothing);
  });

  testWidgets('user overlay stays persisted without a My Connections section', (
    tester,
  ) async {
    final photo = _item(id: 'photo', title: 'Evidence A');
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      title: 'Evidence B',
    );
    await UserConnectionOverlayStore.instance.save(
      incidentId: 'inc-A',
      snapshot: const ConnectionTraceSnapshot(
        links: [
          ConnectionTraceLink(
            fromId: 'photo',
            toId: 'video',
            origin: ConnectionTraceOrigin.user,
          ),
        ],
      ),
    );
    await _pumpTree(tester, evidence: [photo, video]);

    expect(find.text('My Connections'), findsNothing);
    expect(
      UserConnectionOverlayStore.instance.snapshotFor('inc-A')?.links,
      hasLength(1),
    );
  });

  test('mapper does not mutate evidence or relationships', () {
    final photo = _item(id: 'photo');
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      parentEvidenceId: 'photo',
      isContextual: true,
    );
    final relationships = [
      EvidenceRelationship(
        id: 'rel-1',
        sourceEvidenceId: 'photo',
        targetEvidenceId: 'note',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'metadata',
        reason: 'Related because capture times are close.',
      ),
    ];
    final beforeIds = [photo.id, note.id];
    final beforeRel = relationships.single.id;

    final presentation = ConnectionsTreeMapper.from(
      evidence: [photo, note],
      relationships: relationships,
    );

    expect(photo.id, beforeIds[0]);
    expect(note.id, beforeIds[1]);
    expect(relationships.single.id, beforeRel);
    expect(note.parentEvidenceId, 'photo');
    expect(presentation.hasSupporting, isTrue);
    expect(relationships.single.type, RelationshipType.relatedTo);
  });
}
