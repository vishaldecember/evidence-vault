import '../domain/reconstruction/reconstruction_note.dart';
import 'incident_store.dart';

/// Owns [ReconstructionNote] persistence for an incident.
abstract class ReconstructionRepository {
  List<ReconstructionNote> get notes;

  ReconstructionNote add({String? title, required String body});

  ReconstructionNote? update({
    required String noteId,
    String? title,
    required String body,
  });
}

class InMemoryReconstructionRepository implements ReconstructionRepository {
  InMemoryReconstructionRepository(this._store);

  final IncidentStore _store;
  static int _counter = 0;

  @override
  List<ReconstructionNote> get notes =>
      List<ReconstructionNote>.unmodifiable(_store.reconstructionNotes);

  @override
  ReconstructionNote add({String? title, required String body}) {
    final now = DateTime.now();
    final trimmedTitle = title?.trim();
    final note = ReconstructionNote(
      id: _nextId(),
      incidentId: _store.incident.id,
      title: trimmedTitle != null && trimmedTitle.isNotEmpty ? trimmedTitle : null,
      body: body.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _store.reconstructionNotes.insert(0, note);
    _store.incident = _store.incident.copyWith(updatedAt: now);
    return note;
  }

  @override
  ReconstructionNote? update({
    required String noteId,
    String? title,
    required String body,
  }) {
    final index = _store.reconstructionNotes.indexWhere(
      (note) => note.id == noteId,
    );
    if (index == -1) {
      return null;
    }

    final existing = _store.reconstructionNotes[index];
    final trimmedTitle = title?.trim() ?? '';
    final updated = existing.copyWith(
      title: trimmedTitle.isEmpty ? null : trimmedTitle,
      body: body.trim(),
      updatedAt: DateTime.now(),
      clearTitle: trimmedTitle.isEmpty && title != null,
    );
    _store.reconstructionNotes[index] = updated;
    _store.incident = _store.incident.copyWith(updatedAt: updated.updatedAt);
    return updated;
  }

  static String _nextId() {
    _counter += 1;
    return 'reconstruction-note-$_counter';
  }

  static void resetForTests() {
    _counter = 0;
  }
}
