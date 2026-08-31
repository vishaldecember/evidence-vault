import 'package:flutter/material.dart';

/// Canonical event types for the [IncidentTimelineSection].
///
/// Phase 1: evidence preserved and context added.
/// Extension points reserved for relationship created, reflection added,
/// witness statements, verification events, AI observations, and exports.
enum TimelineEventType {
  evidencePreserved,
  contextAdded,
  relationshipCreated,
  reflectionAdded;

  String get label => switch (this) {
        TimelineEventType.evidencePreserved => 'Evidence Preserved',
        TimelineEventType.contextAdded => 'Context Added',
        TimelineEventType.relationshipCreated => 'Relationship Created',
        TimelineEventType.reflectionAdded => 'Reflection Added',
      };

  IconData get icon => switch (this) {
        TimelineEventType.evidencePreserved => Icons.verified_outlined,
        TimelineEventType.contextAdded => Icons.layers_outlined,
        TimelineEventType.relationshipCreated => Icons.link_rounded,
        TimelineEventType.reflectionAdded => Icons.auto_stories_outlined,
      };
}
