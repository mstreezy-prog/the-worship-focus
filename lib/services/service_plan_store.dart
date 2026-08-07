import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/service_plan.dart';

abstract interface class ServicePlanStore {
  Future<List<ServicePlan>?> readPlans();
  Future<void> writePlans(List<ServicePlan> plans);
}

class JsonServicePlanStore implements ServicePlanStore {
  JsonServicePlanStore({this.fileName = 'worship_focus_service_plans.json'});

  final String fileName;

  Future<File> _plansFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  @override
  Future<List<ServicePlan>?> readPlans() async {
    final file = await _plansFile();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<Object?>) {
      throw const FormatException('Saved service plans are not a list');
    }
    return decoded
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Saved service plan entry is invalid');
          }
          return ServicePlan.fromJson(value);
        })
        .toList(growable: false);
  }

  @override
  Future<void> writePlans(List<ServicePlan> plans) async {
    final file = await _plansFile();
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(plans.map((plan) => plan.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }
}
