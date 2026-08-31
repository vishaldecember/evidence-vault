import 'package:evidence_vault/models/relationship_group.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/services/relationship_group_color_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RelationshipGroup _group({
  required String id,
  required int colorIndex,
  DateTime? createdAt,
}) {
  return RelationshipGroup(
    id: id,
    evidenceIds: const ['a', 'b'],
    type: RelationshipType.relatedTo,
    createdAt: createdAt ?? DateTime(2026, 7, 28),
    colorIndex: colorIndex,
  );
}

void main() {
  test('palette progresses Blue Green Purple Orange Amber Teal', () {
    expect(
      RelationshipGroupColorService.colorForIndex(0),
      const Color(0xFF3B36F4),
    );
    expect(
      RelationshipGroupColorService.colorForIndex(1),
      const Color(0xFF16A34A),
    );
    expect(
      RelationshipGroupColorService.colorForIndex(2),
      const Color(0xFF9333EA),
    );
    expect(
      RelationshipGroupColorService.colorForIndex(3),
      const Color(0xFFEA580C),
    );
    expect(
      RelationshipGroupColorService.colorForIndex(4),
      const Color(0xFFF59E0B),
    );
    expect(
      RelationshipGroupColorService.colorForIndex(5),
      const Color(0xFF14B8A6),
    );
  });

  test('nextColorIndex advances with committed group count', () {
    expect(RelationshipGroupColorService.nextColorIndex([]), 0);
    expect(
      RelationshipGroupColorService.nextColorIndex([
        _group(id: 'g1', colorIndex: 0),
      ]),
      1,
    );
    expect(
      RelationshipGroupColorService.nextColorIndex([
        _group(id: 'g1', colorIndex: 0),
        _group(id: 'g2', colorIndex: 1),
      ]),
      2,
    );
  });

  test('colorForGroup uses persisted colorIndex not display order', () {
    final groups = [
      _group(id: 'older', colorIndex: 2, createdAt: DateTime(2026, 7, 28)),
      _group(id: 'newer', colorIndex: 0, createdAt: DateTime(2026, 8, 1)),
    ];

    expect(
      RelationshipGroupColorService.colorForGroup(groups[0]),
      RelationshipGroupColorService.colorForIndex(2),
    );
    expect(
      RelationshipGroupColorService.colorForGroup(groups[1]),
      RelationshipGroupColorService.colorForIndex(0),
    );
  });

  test('groupForEvidence resolves saved group by evidence id', () {
    final group = RelationshipGroup(
      id: 'g1',
      evidenceIds: const ['photo', 'video'],
      type: RelationshipType.relatedTo,
      createdAt: DateTime(2026, 7, 28),
      colorIndex: 1,
    );

    expect(
      RelationshipGroupColorService.groupForEvidence('video', [group])?.id,
      'g1',
    );
    expect(
      RelationshipGroupColorService.groupForEvidence('note', [group]),
      isNull,
    );
  });

  test('displayName follows creation order', () {
    final groups = [
      _group(id: 'g1', colorIndex: 0, createdAt: DateTime(2026, 7, 28)),
      _group(id: 'g2', colorIndex: 1, createdAt: DateTime(2026, 7, 29)),
    ];

    expect(
      RelationshipGroupColorService.displayName(groups[0], groups),
      'Group 1',
    );
    expect(
      RelationshipGroupColorService.displayName(groups[1], groups),
      'Group 2',
    );
  });

  test('displayName uses persisted custom label when set', () {
    final groups = [
      RelationshipGroup(
        id: 'g1',
        evidenceIds: const ['a', 'b'],
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 7, 28),
        colorIndex: 0,
        displayName: '  Entrance Sequence  ',
      ),
    ];

    expect(
      RelationshipGroupColorService.displayName(groups[0], groups),
      'Entrance Sequence',
    );
  });

  test('normalizeDisplayName trims and enforces max length', () {
    expect(
      RelationshipGroupColorService.normalizeDisplayName('  Vehicle Damage  '),
      'Vehicle Damage',
    );
    expect(
      RelationshipGroupColorService.normalizeDisplayName('   '),
      isNull,
    );
    expect(
      RelationshipGroupColorService.normalizeDisplayName('x' * 50)?.length,
      RelationshipGroup.maxDisplayNameLength,
    );
  });

  test('normalizeDescription trims and enforces max length', () {
    expect(
      RelationshipGroupColorService.normalizeDescription('  Reasoning  '),
      'Reasoning',
    );
    expect(
      RelationshipGroupColorService.normalizeDescription('   '),
      isNull,
    );
    expect(
      RelationshipGroupColorService.normalizeDescription('x' * 250)?.length,
      RelationshipGroup.maxDescriptionLength,
    );
  });
}
