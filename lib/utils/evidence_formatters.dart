import 'package:intl/intl.dart';

abstract final class EvidenceFormatters {
  static final _timestamp = DateFormat('MMM d, yyyy • h:mm a');
  static final _fileSizeUnits = ['B', 'KB', 'MB', 'GB'];

  static String timestamp(DateTime dateTime, {String? timezone}) {
    final formatted = _timestamp.format(dateTime);
    if (timezone == null || timezone.isEmpty) {
      return formatted;
    }
    return '$formatted ($timezone)';
  }

  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < _fileSizeUnits.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    final precision = unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${_fileSizeUnits[unitIndex]}';
  }

  static String coordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Location unavailable';
    }

    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}
