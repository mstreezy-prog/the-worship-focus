import 'package:flutter/foundation.dart';

import '../models/score_display_preferences.dart';
import '../services/score_display_preferences_service.dart';

class ScoreDisplayController extends ChangeNotifier {
  ScoreDisplayController({ScoreDisplayPreferencesStore? store})
    : _store = store ?? JsonScoreDisplayPreferencesStore();

  final ScoreDisplayPreferencesStore _store;
  ScoreDisplayPreferences _preferences = const ScoreDisplayPreferences();
  Future<void> _writeQueue = Future<void>.value();

  ScoreDisplayPreferences get preferences => _preferences;

  Future<void> initialize() async {
    try {
      _preferences = await _store.read() ?? const ScoreDisplayPreferences();
    } on Object {
      _preferences = const ScoreDisplayPreferences();
    }
    notifyListeners();
  }

  void setLyricFontSize(double value) {
    _update(_preferences.copyWith(lyricFontSize: value));
  }

  void setChordFontSize(double value) {
    _update(_preferences.copyWith(chordFontSize: value));
  }

  void setNoteSize(double value) {
    _update(_preferences.copyWith(noteSize: value));
  }

  void reset() => _update(const ScoreDisplayPreferences());

  void _update(ScoreDisplayPreferences preferences) {
    if (_preferences.lyricFontSize == preferences.lyricFontSize &&
        _preferences.chordFontSize == preferences.chordFontSize &&
        _preferences.noteSize == preferences.noteSize) {
      return;
    }
    _preferences = preferences;
    notifyListeners();
    _schedulePersistence();
  }

  void _schedulePersistence() {
    final snapshot = _preferences;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _store.write(snapshot);
      } on Object {
        // Score display preferences are restored on the next successful write.
      }
    });
  }
}
