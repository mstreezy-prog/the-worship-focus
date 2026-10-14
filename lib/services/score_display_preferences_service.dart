import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/score_display_preferences.dart';

abstract interface class ScoreDisplayPreferencesStore {
  Future<ScoreDisplayPreferences?> read();
  Future<void> write(ScoreDisplayPreferences preferences);
}

class JsonScoreDisplayPreferencesStore implements ScoreDisplayPreferencesStore {
  JsonScoreDisplayPreferencesStore({
    this.fileName = 'score_display_preferences.json',
  });

  final String fileName;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  @override
  Future<ScoreDisplayPreferences?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid score display preferences');
    }
    return ScoreDisplayPreferences.fromJson(decoded);
  }

  @override
  Future<void> write(ScoreDisplayPreferences preferences) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(preferences.toJson()), flush: true);
  }
}
