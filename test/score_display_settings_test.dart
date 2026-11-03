import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/performance_content.dart';
import 'package:worship_focus_studio/models/score_display_preferences.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/widgets/scrollable_score_view.dart';

import 'fixtures/music_xml_engraving_cases.dart';

void main() {
  testWidgets('Music Stand changes chord appearance independently of notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final song = Song(
      id: 'score-controls',
      title: 'Score controls',
      chordPro: '',
      leadSheet: MusicXmlArrangement(
        fileName: 'test.musicxml',
        sourceXml: beamsXml,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [song],
          initialIndex: 0,
          initialContent: PerformanceContent.leadSheet,
          initialScoreDisplayPreferences: const ScoreDisplayPreferences(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Score display'), findsOneWidget);
    expect(find.text('Chord color'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('score-chord-color-blue')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('score-chord-size')),
      const Offset(100, 0),
    );
    await tester.pump();
    final view = tester.widget<ScrollableScoreView>(
      find.byType(ScrollableScoreView).first,
    );
    expect(view.preferences.chordColor, ScoreChordColor.blue);
    expect(
      view.preferences.chordFontSize,
      greaterThan(ScoreDisplayPreferences.defaultChordFontSize),
    );
    expect(view.preferences.noteSize, ScoreDisplayPreferences.defaultNoteSize);
    expect(
      view.preferences.lyricFontSize,
      ScoreDisplayPreferences.defaultLyricFontSize,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
