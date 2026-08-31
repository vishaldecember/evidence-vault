import 'health_finding_category.dart';
import 'health_finding_priority.dart';
import 'health_finding_status.dart';
import 'health_finding_type.dart';

/// One structured health finding — no presentation copy.
class HealthFinding {
  const HealthFinding({
    required this.id,
    required this.category,
    required this.priority,
    required this.type,
    required this.messageKey,
    this.affectedObjectId,
    required this.recommendationKey,
    this.status = HealthFindingStatus.open,
  });

  final String id;
  final HealthFindingCategory category;
  final HealthFindingPriority priority;
  final HealthFindingType type;
  final String messageKey;
  final String? affectedObjectId;
  final String recommendationKey;
  final HealthFindingStatus status;
}
