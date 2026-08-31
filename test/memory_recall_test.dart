import 'package:evidence_vault/domain/memory/memory_recall_item.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/services/memory/deterministic_memory_recall_provider.dart';
import 'package:evidence_vault/services/memory/memory_recall_preferences.dart';
import 'package:evidence_vault/services/memory/memory_recall_provider.dart';
import 'package:evidence_vault/services/memory/memory_recall_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _summary({
  required String id,
  String title = 'Parking Incident',
  int evidenceCount = 3,
  int contextEnrichedCount = 0,
  bool isInProgress = true,
  bool integrityVerified = false,
  int narrativeCount = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 8, 8);
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: evidenceCount,
    contextEnrichedCount: contextEnrichedCount,
    integrityVerified: integrityVerified,
    lastPreserved: 'today',
    narrativeCount: narrativeCount,
    isInProgress: isInProgress,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? createdAt ?? now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeterministicMemoryRecallProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = const DeterministicMemoryRecallProvider();
    MemoryRecallPreferences.instance.resetForTests();
    MemoryRecallService.instance.resetForTests();
  });

  test('no incidents → empty recall and empty month summary', () async {
    final context = MemoryRecallContext(
      incidents: const [],
      now: DateTime(2026, 8, 8),
    );
    expect(await provider.load(context), isEmpty);
    expect(provider.monthSummary(context).isEmpty, isTrue);
  });

  test('one recent incident → first investigation recall', () async {
    final now = DateTime(2026, 8, 8);
    final items = await provider.load(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'i1',
            createdAt: now.subtract(const Duration(days: 3)),
            updatedAt: now.subtract(const Duration(days: 3)),
          ),
        ],
        now: now,
      ),
    );
    expect(items, isNotEmpty);
    expect(items.first.headline, 'Your first investigation');
    expect(items.first.reason, contains('ago'));
    expect(items.first.incidentId, 'i1');
  });

  test('unresolved / building incidents are prioritized', () async {
    final now = DateTime(2026, 8, 8);
    final items = await provider.load(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'old-done',
            isInProgress: false,
            integrityVerified: true,
            contextEnrichedCount: 2,
            createdAt: now.subtract(const Duration(days: 200)),
            updatedAt: now.subtract(const Duration(days: 200)),
          ),
          _summary(
            id: 'open',
            isInProgress: true,
            evidenceCount: 4,
            contextEnrichedCount: 0,
            createdAt: now.subtract(const Duration(days: 40)),
            updatedAt: now.subtract(const Duration(days: 40)),
          ),
        ],
        now: now,
      ),
    );
    expect(items.first.incidentId, 'open');
    expect(
      items.first.type,
      anyOf(
        MemoryRecallType.unresolvedIncident,
        MemoryRecallType.unreviewedEvidence,
        MemoryRecallType.buildingIncident,
      ),
    );
  });

  test('old unresolved incident surfaces forgotten recall', () async {
    final now = DateTime(2026, 8, 8);
    final items = await provider.load(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'ancient',
            evidenceCount: 2,
            contextEnrichedCount: 1,
            createdAt: now.subtract(const Duration(days: 140)),
            updatedAt: now.subtract(const Duration(days: 140)),
          ),
          _summary(
            id: 'other',
            title: 'Other',
            createdAt: now.subtract(const Duration(days: 10)),
            updatedAt: now.subtract(const Duration(days: 10)),
          ),
        ],
        now: now,
      ),
    );
    expect(items.any((i) => i.incidentId == 'ancient'), isTrue);
    final old = items.firstWhere((i) => i.incidentId == 'ancient');
    expect(old.reason, isNot(contains('AI')));
  });

  test('recently strengthened readiness produces recently changed recall',
      () async {
    final now = DateTime(2026, 8, 8);
    final items = await provider.load(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'ready',
            isInProgress: false,
            integrityVerified: true,
            contextEnrichedCount: 3,
            createdAt: now.subtract(const Duration(days: 60)),
            updatedAt: now.subtract(const Duration(days: 2)),
          ),
          _summary(id: 'peer'),
        ],
        now: now,
      ),
    );
    expect(
      items.any((i) => i.type == MemoryRecallType.recentlyChanged),
      isTrue,
    );
  });

  test('unreviewed evidence recall references real evidence count', () async {
    final now = DateTime(2026, 8, 8);
    final items = await provider.load(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'bare',
            evidenceCount: 7,
            contextEnrichedCount: 0,
            createdAt: now.subtract(const Duration(days: 20)),
            updatedAt: now.subtract(const Duration(days: 20)),
          ),
          _summary(id: 'peer2'),
        ],
        now: now,
      ),
    );
    final match = items.firstWhere(
      (i) => i.type == MemoryRecallType.unreviewedEvidence,
      orElse: () => items.first,
    );
    expect(match.reason, contains('7'));
    expect(match.evidenceCount, 7);
  });

  test('dismissed recall is excluded; underlying incident untouched', () async {
    final now = DateTime(2026, 8, 8);
    final incident = _summary(
      id: 'd1',
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 5)),
    );
    final before = await provider.load(
      MemoryRecallContext(incidents: [incident], now: now),
    );
    expect(before, isNotEmpty);
    final id = before.first.id;

    await MemoryRecallPreferences.instance.dismiss(id, now: now);
    final after = await provider.load(
      MemoryRecallContext(
        incidents: [incident],
        now: now,
        dismissedIds: MemoryRecallPreferences.instance.activeDismissedIds(
          now: now,
        ),
      ),
    );
    expect(after.any((i) => i.id == id), isFalse);
  });

  test('no duplicate incident cards in top results', () async {
    final now = DateTime(2026, 8, 8);
    final items = await provider.load(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'multi',
            evidenceCount: 8,
            contextEnrichedCount: 0,
            createdAt: now.subtract(const Duration(days: 100)),
            updatedAt: now.subtract(const Duration(days: 100)),
          ),
        ],
        now: now,
      ),
    );
    expect(items.map((i) => i.incidentId).toSet(), hasLength(items.length));
  });

  test('This Month summary uses only current-month incidents', () {
    final now = DateTime(2026, 8, 8);
    final summary = provider.monthSummary(
      MemoryRecallContext(
        incidents: [
          _summary(
            id: 'aug',
            evidenceCount: 5,
            contextEnrichedCount: 1,
            updatedAt: DateTime(2026, 8, 2),
          ),
          _summary(
            id: 'jul',
            evidenceCount: 9,
            updatedAt: DateTime(2026, 7, 1),
          ),
        ],
        now: now,
      ),
    );
    expect(summary.evidenceCaptured, 5);
    expect(summary.incidentsTouched, 1);
    expect(summary.investigationsStrengthened, 1);
  });

  test('fabricated memories are impossible without incident ids', () async {
    final items = await provider.load(
      MemoryRecallContext(incidents: const [], now: DateTime(2026, 8, 8)),
    );
    expect(items, isEmpty);
  });
}
