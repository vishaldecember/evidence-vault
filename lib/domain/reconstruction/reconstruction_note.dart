/// Investigative notes preserved during incident reconstruction preparation.
///
/// Domain successor to legacy Reflection terminology. UI may still reference
/// Reflection labels via compatibility typedefs.
class ReconstructionNote {
  const ReconstructionNote({
    required this.id,
    this.incidentId = '',
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  final String id;
  final String incidentId;
  final String? title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  ReconstructionNote copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    bool clearTitle = false,
  }) {
    return ReconstructionNote(
      id: id,
      incidentId: incidentId,
      title: clearTitle ? null : (title ?? this.title),
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
