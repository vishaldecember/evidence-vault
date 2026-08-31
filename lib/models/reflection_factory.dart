import 'reflection_model.dart';

abstract final class ReflectionFactory {
  static int _counter = 0;

  static String _nextId() {
    _counter += 1;
    return 'ws-reflection-$_counter';
  }

  static ReflectionModel create({
    String? title,
    required String body,
  }) {
    final now = DateTime.now();
    final trimmedTitle = title?.trim();
    return ReconstructionNote(
      id: _nextId(),
      title: trimmedTitle != null && trimmedTitle.isNotEmpty
          ? trimmedTitle
          : null,
      body: body.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  static void resetForTests() {
    _counter = 0;
  }
}
