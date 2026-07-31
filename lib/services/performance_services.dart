import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/performance_preferences.dart';

abstract interface class PerformancePreferencesStore {
  Future<PerformancePreferences?> read();
  Future<void> write(PerformancePreferences preferences);
}

class JsonPerformancePreferencesStore implements PerformancePreferencesStore {
  JsonPerformancePreferencesStore({
    this.fileName = 'performance_preferences.json',
  });

  final String fileName;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  @override
  Future<PerformancePreferences?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid performance preferences');
    }
    return PerformancePreferences.fromJson(decoded);
  }

  @override
  Future<void> write(PerformancePreferences preferences) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(preferences.toJson()), flush: true);
  }
}

abstract interface class KeepAwakeService {
  Future<void> setEnabled(bool enabled);
}

class WakelockKeepAwakeService implements KeepAwakeService {
  @override
  Future<void> setEnabled(bool enabled) {
    return WakelockPlus.toggle(enable: enabled);
  }
}
