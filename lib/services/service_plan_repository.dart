import '../models/service_plan.dart';
import 'service_plan_store.dart';

class ServicePlanRepository {
  ServicePlanRepository({ServicePlanStore? store, Iterable<ServicePlan>? seed})
    : _store = store ?? JsonServicePlanStore(),
      _plans = (seed ?? const <ServicePlan>[]).toList();

  final ServicePlanStore _store;
  final List<ServicePlan> _plans;

  List<ServicePlan> getAll() => List.unmodifiable(_plans);

  Future<List<ServicePlan>> load() async {
    final savedPlans = await _store.readPlans();
    if (savedPlans != null) {
      _plans
        ..clear()
        ..addAll(savedPlans);
    }
    return getAll();
  }

  void add(ServicePlan plan) => _plans.add(plan);

  void update(ServicePlan plan) {
    final index = _plans.indexWhere((candidate) => candidate.id == plan.id);
    if (index != -1) _plans[index] = plan;
  }

  void delete(String id) => _plans.removeWhere((plan) => plan.id == id);

  Future<void> persist() => _store.writePlans(getAll());
}
