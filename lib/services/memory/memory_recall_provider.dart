import '../../domain/memory/memory_recall_item.dart';
import '../../models/library_incident_summary.dart';

/// Context for Memory Recall generation — library data only (Sprint 5D).
class MemoryRecallContext {
  const MemoryRecallContext({
    required this.incidents,
    required this.now,
    this.dismissedIds = const {},
  });

  final List<LibraryIncidentSummary> incidents;
  final DateTime now;
  final Set<String> dismissedIds;
}

/// Future AI providers implement this — UI never knows which provider ran.
///
/// Reserved (not implemented): [AIMemoryRecallProvider] and ambient “Whisper”
/// insights that may reuse [MemoryRecallItem] without changing Vault UI.
abstract class MemoryRecallProvider {
  Future<List<MemoryRecallItem>> load(MemoryRecallContext context);

  MemoryMonthSummary monthSummary(MemoryRecallContext context);
}
