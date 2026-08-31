import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/organize/organize_context_anchor.dart';
import '../../repositories/incident_store.dart';
import '../organize/organize_context_anchor_store.dart';

/// Durable Organize toolbar-origin + explicit context→evidence relationships.
///
/// Origin means "floating fairy" — never a chronology-spine member.
/// Anchors are relationships only; they do not place context onto the spine.
/// Session memory is still the live source of truth; this payload is restored
/// after hydrate/restart.
abstract final class OrganizeContextPersistence {
  static const keyPrefix = 'ev_organize_context_v1_';

  static String keyFor(String incidentId) => '$keyPrefix$incidentId';

  static Future<void> save({
    required String incidentId,
    required Set<String> createdIds,
    required List<OrganizeContextAnchor> anchors,
  }) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyFor(id),
        jsonEncode({
          'createdIds': createdIds.toList(),
          'anchors': [for (final anchor in anchors) anchor.toJson()],
        }),
      );
    } catch (_) {
      // Tests without a SharedPreferences mock, or before binding init.
    }
  }

  /// Merges persisted origin/snaps into [store] for evidence that still exists.
  ///
  /// Adds only. Never creates evidence, never writes chronology, never infers
  /// a snap from layout or parent/relationship fields.
  static Future<bool> applyTo(IncidentStore store) async {
    final loaded = await load(store.incident.id);
    if (loaded == null) {
      return false;
    }
    return applyPayload(store, loaded);
  }

  @visibleForTesting
  static Future<({Set<String> createdIds, List<OrganizeContextAnchor> anchors})?>
      load(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(id));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final created = <String>{};
      final createdRaw = map['createdIds'];
      if (createdRaw is List) {
        for (final item in createdRaw) {
          if (item is String && item.trim().isNotEmpty) {
            created.add(item.trim());
          }
        }
      }
      final anchors = <OrganizeContextAnchor>[];
      final anchorsRaw = map['anchors'];
      if (anchorsRaw is List) {
        for (final item in anchorsRaw) {
          final anchor = OrganizeContextAnchor.fromJson(item);
          if (anchor != null) {
            anchors.add(anchor);
          }
        }
      }
      return (createdIds: created, anchors: anchors);
    } catch (error) {
      debugPrint('[OrganizeContext] load failed: $error');
      return null;
    }
  }

  @visibleForTesting
  static bool applyPayload(
    IncidentStore store,
    ({Set<String> createdIds, List<OrganizeContextAnchor> anchors}) payload,
  ) {
    final existingIds = {
      for (final item in store.capturedEvidence) item.id,
      for (final item in store.supportingEvidence) item.id,
    };
    var changed = false;
    for (final id in payload.createdIds) {
      if (!existingIds.contains(id)) {
        continue;
      }
      changed = store.organizeCreatedEvidenceIds.add(id) || changed;
    }

    final alreadySnapped = {
      for (final anchor in store.organizeContextAnchors) anchor.contextEvidenceId,
    };
    for (final anchor in payload.anchors) {
      if (alreadySnapped.contains(anchor.contextEvidenceId)) {
        continue;
      }
      if (!store.organizeCreatedEvidenceIds.contains(anchor.contextEvidenceId)) {
        continue;
      }
      final written = OrganizeContextAnchorStore.instance.setAnchor(
        store: store,
        contextEvidenceId: anchor.contextEvidenceId,
        capturedEvidenceId: anchor.capturedEvidenceId,
      );
      if (written != null) {
        alreadySnapped.add(written.contextEvidenceId);
        changed = true;
      }
    }
    return changed;
  }

  static Future<void> clearForIncident(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFor(id));
    } catch (error) {
      debugPrint('[OrganizeContext] clearForIncident skipped: $error');
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(keyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (error) {
      debugPrint('[OrganizeContext] clear failed: $error');
    }
  }
}
