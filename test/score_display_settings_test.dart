import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/performance_content.dart';
import 'package:worship_focus_studio/models/score_display_preferences.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/services/notation_renderer.dart';
import 'package:worship_focus_studio/widgets/scrollable_score_view.dart';

import 'fixtures/music_xml_engraving_cases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(NotationRenderer.initialize);

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets(
      'Music Stand changes chord appearance independently of notes at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousHitTestPolicy =
            WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(
          () => WidgetController.hitTestWarningShouldBeFatal =
              previousHitTestPolicy,
        );
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
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Reader settings'));
        // The first frame starts the route animation. Pumping one delayed frame
        // leaves the sheet at its initial off-screen position.
        await tester.pumpAndSettle();
        expect(find.text('Score display'), findsOneWidget);
        expect(find.text('Chord color'), findsOneWidget);
        final blue = find.byKey(const ValueKey('score-chord-color-blue'));
        await tester.ensureVisible(blue);
        await tester.pumpAndSettle();
        expect(blue.hitTestable(), findsOneWidget);
        await tester.tap(blue);
        await tester.pumpAndSettle();
        final chordSize = find.byKey(const ValueKey('score-chord-size'));
        await tester.ensureVisible(chordSize);
        await tester.pumpAndSettle();
        expect(chordSize.hitTestable(), findsOneWidget);
        await tester.drag(chordSize, const Offset(100, 0));
        await tester.pumpAndSettle();
        final view = tester.widget<ScrollableScoreView>(
          find.byType(ScrollableScoreView).first,
        );
        expect(view.preferences.chordColor, ScoreChordColor.blue);
        expect(
          view.preferences.chordFontSize,
          greaterThan(ScoreDisplayPreferences.defaultChordFontSize),
        );
        expect(
          view.preferences.noteSize,
          ScoreDisplayPreferences.defaultNoteSize,
        );
        expect(
          view.preferences.lyricFontSize,
          ScoreDisplayPreferences.defaultLyricFontSize,
        );
        Navigator.of(tester.element(find.text('Score display'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Reader settings'));
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(blue).selected, isTrue);
        expect(
          tester.widget<Slider>(chordSize).value,
          view.preferences.chordFontSize,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
