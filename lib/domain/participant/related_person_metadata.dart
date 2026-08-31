import 'dart:convert';

import 'related_person_link.dart';

/// Per-evidence related-person fields stored on evidence metadata.
///
/// People are a collection. Legacy single keys remain the first person so
/// existing hydrate and graph code keep working. The shared [Participant]
/// is the stable identity; these keys keep name + relationship on the
/// evidence so Inspector display survives when the participant list is empty.
abstract final class RelatedPersonMetadata {
  static const idKey = 'relatedPersonId';
  static const nameKey = 'relatedPersonName';
  static const roleKey = 'relatedPersonRole';
  static const peopleKey = 'relatedPeople';

  /// Replaces the entire related-person collection with zero or one person.
  ///
  /// Used by legacy assign. Adding a second person must use [addPerson].
  static Map<String, String> merge({
    required Map<String, String> current,
    String? participantId,
    String? displayName,
    String? roleName,
  }) {
    if (participantId == null ||
        participantId.isEmpty ||
        displayName == null ||
        displayName.trim().isEmpty) {
      return writePeople(current, const []);
    }
    return writePeople(current, [
      RelatedPersonLink(
        participantId: participantId,
        displayName: displayName.trim(),
        roleName: roleName,
      ),
    ]);
  }

  static Map<String, String> writePeople(
    Map<String, String> current,
    List<RelatedPersonLink> people,
  ) {
    final next = Map<String, String>.from(current);
    next.remove(idKey);
    next.remove(nameKey);
    next.remove(roleKey);
    next.remove(peopleKey);
    if (people.isEmpty) {
      return next;
    }
    final first = people.first;
    next[idKey] = first.participantId;
    next[nameKey] = first.displayName.trim();
    final firstRole = first.roleName?.trim();
    if (firstRole != null && firstRole.isNotEmpty) {
      next[roleKey] = firstRole;
    }
    next[peopleKey] = jsonEncode([
      for (final person in people) _encodePerson(person),
    ]);
    return next;
  }

  static Map<String, String> addPerson({
    required Map<String, String> current,
    required String participantId,
    required String displayName,
    String? roleName,
  }) {
    final trimmedName = displayName.trim();
    if (participantId.trim().isEmpty || trimmedName.isEmpty) {
      return Map<String, String>.from(current);
    }
    final people = [...peopleOf(current)];
    final id = participantId.trim();
    final index = people.indexWhere((person) => person.participantId == id);
    final link = RelatedPersonLink(
      participantId: id,
      displayName: trimmedName,
      roleName: roleName,
    );
    if (index >= 0) {
      people[index] = link;
    } else {
      people.add(link);
    }
    return writePeople(current, people);
  }

  static Map<String, String> replacePerson({
    required Map<String, String> current,
    required String previousParticipantId,
    required String participantId,
    required String displayName,
    String? roleName,
  }) {
    final people = [...peopleOf(current)];
    final previous = previousParticipantId.trim();
    final index = people.indexWhere((person) => person.participantId == previous);
    if (index < 0) {
      return addPerson(
        current: current,
        participantId: participantId,
        displayName: displayName,
        roleName: roleName,
      );
    }
    people[index] = RelatedPersonLink(
      participantId: participantId.trim(),
      displayName: displayName.trim(),
      roleName: roleName,
    );
    return writePeople(current, people);
  }

  static Map<String, String> removePerson({
    required Map<String, String> current,
    required String participantId,
  }) {
    final id = participantId.trim();
    final people = [
      for (final person in peopleOf(current))
        if (person.participantId != id) person,
    ];
    return writePeople(current, people);
  }

  static List<RelatedPersonLink> peopleOf(Map<String, String> metadata) {
    final raw = metadata[peopleKey]?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = <RelatedPersonLink>[];
          for (final entry in decoded) {
            if (entry is Map) {
              final person = _decodePerson(entry);
              if (person != null) {
                parsed.add(person);
              }
            }
          }
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } catch (_) {}
    }
    final name = nameOf(metadata);
    if (name == null) {
      return const [];
    }
    return [
      RelatedPersonLink(
        participantId: idOf(metadata) ?? '',
        displayName: name,
        roleName: roleOf(metadata),
      ),
    ];
  }

  static String? idOf(Map<String, String> metadata) =>
      _nonEmpty(metadata[idKey]);

  static String? nameOf(Map<String, String> metadata) =>
      _nonEmpty(metadata[nameKey]);

  static String? roleOf(Map<String, String> metadata) =>
      _nonEmpty(metadata[roleKey]);

  static Map<String, String> _encodePerson(RelatedPersonLink person) {
    return {
      'id': person.participantId,
      'name': person.displayName,
      if (person.roleName != null && person.roleName!.trim().isNotEmpty)
        'role': person.roleName!.trim(),
    };
  }

  static RelatedPersonLink? _decodePerson(Map<dynamic, dynamic> entry) {
    final name = _nonEmpty(entry['name']?.toString());
    if (name == null) {
      return null;
    }
    return RelatedPersonLink(
      participantId: (entry['id']?.toString() ?? '').trim(),
      displayName: name,
      roleName: _nonEmpty(entry['role']?.toString()),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
