import '../domain/reconstruction/reconstruction_note.dart';

export '../domain/reconstruction/reconstruction_note.dart';

/// Personal understanding preserved after evidence — never auto-generated.
///
/// Domain type is [ReconstructionNote]. [ReflectionModel] remains as a
/// compatibility alias for existing UI and engines.
typedef ReflectionModel = ReconstructionNote;

/// Canonical Reflection prompt — do not paraphrase.
abstract final class ReflectionPrompts {
  static const String canonical =
      'What did you learn when you looked back?';
}
