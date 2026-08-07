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
