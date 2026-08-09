import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/service_plan.dart';
import 'package:worship_focus_studio/services/service_plan_repository.dart';
import 'package:worship_focus_studio/services/service_plan_store.dart';

class _MemoryServicePlanStore implements ServicePlanStore {
  List<ServicePlan>? savedPlans;

  @override
  Future<List<ServicePlan>?> readPlans() async => savedPlans;

  @override
  Future<void> writePlans(List<ServicePlan> plans) async {
    savedPlans = List.of(plans);
  }
}

void main() {
  test('a service plan round-trips through JSON', () {
    final plan = ServicePlan(
      id: 'plan-1',
      title: 'Sunday Morning',
      date: DateTime.utc(2026, 8, 9),
      songIds: const ['song-1', 'song-2'],
    );

    final restored = ServicePlan.fromJson(plan.toJson());

    expect(restored.id, plan.id);
    expect(restored.title, plan.title);
    expect(restored.date, plan.date);
    expect(restored.songIds, plan.songIds);
  });

  test('keeps section text and song notes in their saved order', () {
    final plan = ServicePlan(
      id: 'plan-1',
      title: 'Sunday Morning',
      date: DateTime.utc(2026, 8, 9),
      items: const [
        ServicePlanItem.section(
          id: 'section-1',
          title: 'Welcome',
          notes: 'Invite the congregation to stand and pray together.',
        ),
        ServicePlanItem.song(
          id: 'song-1',
          songId: 'amazing-grace',
          notes: 'Start in G; repeat the chorus.',
        ),
      ],
    );

    final restored = ServicePlan.fromJson(plan.toJson());

    expect(restored.items, hasLength(2));
    expect(restored.items.first.title, 'Welcome');
    expect(
      restored.items.first.notes,
      'Invite the congregation to stand and pray together.',
    );
    expect(restored.items.last.songId, 'amazing-grace');
    expect(restored.items.last.notes, 'Start in G; repeat the chorus.');
  });

  test('loads plans saved by the earlier song-only format', () {
    final plan = ServicePlan.fromJson({
      'id': 'plan-1',
      'title': 'Sunday Morning',
      'date': '2026-08-09T00:00:00.000Z',
      'songIds': ['song-1', 'song-2'],
    });

    expect(plan.items.map((item) => item.songId), ['song-1', 'song-2']);
  });

  test('repository persists its service plans', () async {
    final store = _MemoryServicePlanStore();
    final repository = ServicePlanRepository(store: store);
    final plan = ServicePlan(
      id: 'plan-1',
      title: 'Sunday Morning',
      date: DateTime.utc(2026, 8, 9),
      songIds: const ['song-1'],
    );

    repository.add(plan);
    await repository.persist();

    final restored = ServicePlanRepository(store: store);
    await restored.load();
    expect(restored.getAll(), hasLength(1));
    expect(restored.getAll().single.songIds, const ['song-1']);
  });
}
