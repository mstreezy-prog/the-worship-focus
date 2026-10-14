import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/controllers/score_display_controller.dart';
import 'package:worship_focus_studio/models/score_display_preferences.dart';
import 'package:worship_focus_studio/services/score_display_preferences_service.dart';

class _MemoryScoreDisplayStore implements ScoreDisplayPreferencesStore {
  ScoreDisplayPreferences? saved;

  @override
  Future<ScoreDisplayPreferences?> read() async => saved;

  @override
  Future<void> write(ScoreDisplayPreferences preferences) async {
    saved = ScoreDisplayPreferences.fromJson(preferences.toJson());
  }
}

void main() {
  test('score display preferences round-trip and enforce safe ranges', () {
    final preferences = ScoreDisplayPreferences.fromJson({
      'lyricFontSize': 100,
      'chordFontSize': 2,
      'noteSize': 50,
    });

    expect(
      preferences.lyricFontSize,
      ScoreDisplayPreferences.maximumLyricFontSize,
    );
    expect(
      preferences.chordFontSize,
      ScoreDisplayPreferences.minimumChordFontSize,
    );
    expect(preferences.noteSize, ScoreDisplayPreferences.maximumNoteSize);
    expect(preferences.staffGap, 234);
    expect(preferences.interSystemGap, 162);
  });

  test('controller persists each independent score size', () async {
    final store = _MemoryScoreDisplayStore();
    final controller = ScoreDisplayController(store: store);
    await controller.initialize();

    controller
      ..setLyricFontSize(22)
      ..setChordFontSize(26)
      ..setNoteSize(15);
    await Future<void>.delayed(Duration.zero);

    expect(store.saved!.lyricFontSize, 22);
    expect(store.saved!.chordFontSize, 26);
    expect(store.saved!.noteSize, 15);
    controller.dispose();
  });
}
