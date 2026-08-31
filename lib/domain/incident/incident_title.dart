/// Incident display-title helpers. Not a validation framework.
abstract final class IncidentTitle {
  static const placeholder = 'Untitled Incident';

  /// Empty, whitespace, and the system placeholder are not meaningful.
  static bool isMeaningful(String? title) {
    final trimmed = title?.trim() ?? '';
    if (trimmed.isEmpty) {
      return false;
    }
    return trimmed.toLowerCase() != placeholder.toLowerCase();
  }

  static bool isPlaceholder(String? title) => !isMeaningful(title);

  static String display(String? title) {
    final trimmed = title?.trim() ?? '';
    return trimmed.isEmpty ? placeholder : trimmed;
  }
}
