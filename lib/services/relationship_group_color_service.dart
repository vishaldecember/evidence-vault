import 'package:flutter/material.dart';

import '../models/relationship_group.dart';

/// Single source of truth for Relationship Group colour assignment and lookup.
abstract final class RelationshipGroupColorService {
  static const List<Color> palette = [
    Color(0xFF3B36F4), // Blue — Group 1
    Color(0xFF16A34A), // Green — Group 2
    Color(0xFF9333EA), // Purple — Group 3
    Color(0xFFEA580C), // Orange — Group 4
    Color(0xFFF59E0B), // Amber — Group 5
    Color(0xFF14B8A6), // Teal — Group 6
  ];

  static int nextColorIndex(List<RelationshipGroup> existingGroups) =>
      existingGroups.length % palette.length;

  static Color colorForIndex(int colorIndex) =>
      palette[colorIndex % palette.length];

  static Color colorForGroup(RelationshipGroup group) =>
      colorForIndex(group.colorIndex);

  static Color nextAvailableColor(List<RelationshipGroup> groups) =>
      colorForIndex(nextColorIndex(groups));

  static List<RelationshipGroup> orderedGroups(
    List<RelationshipGroup> groups,
  ) {
    return List<RelationshipGroup>.from(groups)
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        if (byTime != 0) {
          return byTime;
        }
        return a.id.compareTo(b.id);
      });
  }

  static int displayNumber(
    RelationshipGroup group,
    List<RelationshipGroup> allGroups,
  ) {
    final index = orderedGroups(allGroups).indexWhere((g) => g.id == group.id);
    return index < 0 ? group.colorIndex + 1 : index + 1;
  }

  static String displayName(
    RelationshipGroup group,
    List<RelationshipGroup> allGroups,
  ) {
    final custom = group.displayName?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return 'Group ${displayNumber(group, allGroups)}';
  }

  /// Normalizes investigator input for [RelationshipGroup.displayName].
  static String? normalizeDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > RelationshipGroup.maxDisplayNameLength) {
      return trimmed.substring(0, RelationshipGroup.maxDisplayNameLength);
    }
    return trimmed;
  }

  /// Normalizes investigator input for [RelationshipGroup.description].
  static String? normalizeDescription(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > RelationshipGroup.maxDescriptionLength) {
      return trimmed.substring(0, RelationshipGroup.maxDescriptionLength);
    }
    return trimmed;
  }

  static RelationshipGroup? groupForEvidence(
    String evidenceId,
    List<RelationshipGroup> groups,
  ) {
    final matches = groupsForEvidence(evidenceId, groups);
    return matches.isEmpty ? null : matches.first;
  }

  /// Every relationship group containing [evidenceId], in display order.
  static List<RelationshipGroup> groupsForEvidence(
    String evidenceId,
    List<RelationshipGroup> groups,
  ) {
    return orderedGroups(groups)
        .where((group) => group.evidenceIds.contains(evidenceId))
        .toList(growable: false);
  }
}
