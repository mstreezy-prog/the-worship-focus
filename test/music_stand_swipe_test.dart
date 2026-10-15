import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/performance_content.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';
import 'package:worship_focus_studio/models/score_display_preferences.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/music_xml_viewer_screen.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/services/notation_renderer.dart';
import 'package:worship_focus_studio/services/music_stand_page_sequence.dart';
import 'package:worship_focus_studio/widgets/scrollable_score_view.dart';

String longXml() =>
    '''<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Melody</part-name></score-part></part-list><part id="P1">
${List.generate(80, (i) => '''<measure number="${i + 1}">${i == 0 ? '<attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>' : ''}<note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure>''').join()}
</part></score-partwise>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(NotationRenderer.initialize);

  void iPad(WidgetTester tester) {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void iosTest(String name, WidgetTesterCallback callback) => testWidgets(
    name,
    callback,
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  Future<void> loadScore(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  test('wrapped staff fragments get single automatic ending bars', () {
    final staff = MusicXMLParser.scoreFromMusicXML(
      longXml(),
    ).staffGroups.first.staves.first;
    final layout = LayoutEngine(
      staff,
      availableWidth: 804,
      metadata: SmuflMetadata(),
      automaticFinalBarline: false,
    ).layout();
    final bars = layout
        .where((item) => item.element is Barline)
        .map((item) => item.element as Barline)
        .toList();
    expect(bars, isNotEmpty);
    expect(bars.every((bar) => bar.type == BarlineType.single), isTrue);
    final normalPiece = LayoutEngine(
      staff,
      availableWidth: 804,
      metadata: SmuflMetadata(),
    ).layout();
    expect(
      (normalPiece.lastWhere((item) => item.element is Barline).element
              as Barline)
          .type,
      BarlineType.final_,
    );
  });

  test('explicit final and repeat bars survive fragment layout', () {
    for (final type in [
      BarlineType.final_,
      BarlineType.double,
      BarlineType.repeatBackward,
    ]) {
      final staff = MusicXMLParser.scoreFromMusicXML(
        longXml(),
      ).staffGroups.first.staves.first;
      staff.measures.last.add(Barline(type: type));
      final layout = LayoutEngine(
        staff,
        availableWidth: 804,
        metadata: SmuflMetadata(),
        automaticFinalBarline: false,
      ).layout();
      expect(
        (layout.lastWhere((item) => item.element is Barline).element as Barline)
            .type,
        type,
      );
    }
  });

  test('page sequence places all chart pages before the next song', () {
    final sequence = MusicStandPageSequence([2, 1, 3]);
    expect(sequence.pages.map((page) => [page.songIndex, page.chartPage]), [
      [0, 0],
      [0, 1],
      [1, 0],
      [2, 0],
      [2, 1],
      [2, 2],
    ]);
    expect(sequence.indexFor(2, 1), 4);
    expect(sequence.indexFor(0, 99), 1);
    expect(sequence.hasSameLayout(MusicStandPageSequence([2, 1, 3])), isTrue);
    expect(sequence.hasSameLayout(MusicStandPageSequence([1, 1, 3])), isFalse);
  });

  iosTest('iOS swipes turn chart pages then songs in both directions', (
    tester,
  ) async {
    iPad(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [
            Song(
              id: 'a',
              title: 'Long Song',
              chordPro: List.generate(
                50,
                (index) => '[C]Line $index',
              ).join('\n'),
            ),
            Song(id: 'b', title: 'Next Song', chordPro: '[G]Peace'),
          ],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reader = find.byKey(const ValueKey('music-stand-song-reader'));
    final pager = tester.widget<PageView>(reader);
    final chartCount = pager.childrenDelegate.estimatedChildCount! - 1;
    expect(chartCount, greaterThan(2));
    expect(find.byType(PageView), findsOneWidget);
    if (find.byTooltip('Pencil').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Pencil tools'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Pencil'));
    await tester.pump();
    await tester.fling(reader, const Offset(-200, 0), 1800);
    await tester.pumpAndSettle();
    expect(find.textContaining('Long Song  •'), findsOneWidget);
    expect(find.text('Page 2/$chartCount'), findsOneWidget);
    expect(pager.controller!.page, 1);
    pager.controller!.jumpToPage(chartCount - 1);
    await tester.pumpAndSettle();
    await tester.drag(reader, const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Next Song  •'), findsOneWidget);
    await tester.drag(reader, const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Long Song  •'), findsOneWidget);
    expect(find.text('Page $chartCount/$chartCount'), findsOneWidget);
    await tester.drag(reader, const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(find.text('Page ${chartCount - 1}/$chartCount'), findsOneWidget);
    await tester.tap(find.byTooltip('Next song'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Next Song  •'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous song'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1/$chartCount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  iosTest('selected song survives initial page offsets and rotation reflow', (
    tester,
  ) async {
    iPad(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [
            Song(
              id: 'first',
              title: 'Earlier Song',
              chordPro: List.generate(
                50,
                (index) => '[C]Earlier $index',
              ).join('\n'),
            ),
            Song(
              id: 'selected',
              title: 'Selected Song',
              chordPro: List.generate(
                35,
                (index) => '[G]Selected $index',
              ).join('\n'),
            ),
          ],
          initialIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reader = find.byKey(const ValueKey('music-stand-song-reader'));
    final pager = tester.widget<PageView>(reader);
    final start = pager.controller!.page!;
    expect(start, greaterThan(0));
    expect(find.textContaining('Selected Song  •'), findsOneWidget);
    await tester.drag(reader, const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(pager.controller!.page, start + 1);
    tester.view.physicalSize = const Size(820, 1180);
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected Song  •'), findsOneWidget);
    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase font size'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Reader settings'))).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected Song  •'), findsOneWidget);
    expect(find.textContaining('Page 1/'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  iosTest('one-page iOS song swipes work without an overscroll gesture', (
    tester,
  ) async {
    iPad(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [
            Song(id: 'a', title: 'First Song', chordPro: '[C]Grace'),
            Song(id: 'b', title: 'Second Song', chordPro: '[G]Peace'),
          ],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final songs = find.byKey(const ValueKey('music-stand-song-reader'));
    await tester.drag(songs, const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Second Song  •'), findsOneWidget);
    await tester.drag(songs, const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('First Song  •'), findsOneWidget);
  });

  iosTest('XML scrolls vertically while horizontal swipes change songs', (
    tester,
  ) async {
    iPad(tester);
    List<ScoreAnnotationStroke> saved = [];
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          songs: [
            Song(
              id: 'xml',
              title: 'Long Score',
              chordPro: '[C]Chart',
              leadSheet: MusicXmlArrangement(
                fileName: 'score.musicxml',
                sourceXml: longXml(),
              ),
            ),
            Song(id: 'next', title: 'Next Song', chordPro: '[G]Peace'),
          ],
          initialIndex: 0,
          initialContent: PerformanceContent.leadSheet,
          initialScoreDisplayPreferences: const ScoreDisplayPreferences(),
          onScoreAnnotationsChanged: (_, type, strokes) => saved = strokes,
        ),
      ),
    );
    await loadScore(tester);
    final vertical = find.byKey(const ValueKey('xml-vertical-reader'));
    final scroll = tester.widget<SingleChildScrollView>(vertical).controller!;
    await tester.drag(vertical, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(find.textContaining('Long Score  •'), findsOneWidget);
    if (find.byTooltip('Pencil').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Pencil tools'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Pencil'));
    await tester.pump();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await gesture.down(tester.getCenter(vertical));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    final y = saved.single.points.first.y;
    tester.view.physicalSize = const Size(820, 1180);
    await tester.pumpAndSettle();
    expect(saved.single.points.first.y, y);
    await tester.drag(
      find.byKey(const ValueKey('music-stand-song-reader')),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Next Song  •'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  iosTest('XML viewer pans vertically and Go live retains all songs', (
    tester,
  ) async {
    iPad(tester);
    final song = Song(
      id: 'xml',
      title: 'Score',
      chordPro: '',
      leadSheet: MusicXmlArrangement(
        fileName: 'score.musicxml',
        sourceXml: longXml(),
      ),
    );
    final next = Song(id: 'next', title: 'Next Song', chordPro: '[G]Peace');
    await tester.pumpWidget(
      MaterialApp(
        home: MusicXmlViewerScreen(
          song: song,
          performanceSongs: [song, next],
          initialType: MusicXmlArrangementType.leadSheet,
          onTranspose: (_, _) {},
          onAnnotationsChanged: (_, _) {},
        ),
      ),
    );
    await loadScore(tester);
    final reader = find.byKey(const ValueKey('xml-vertical-viewer'));
    final view = tester.widget<InteractiveViewer>(reader);
    await tester.drag(reader, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(
      view.transformationController!.value.getTranslation().y,
      lessThan(0),
    );
    await tester.tap(find.byTooltip('Fit score'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(
      view.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    expect(find.byType(ScrollableScoreView), findsOneWidget);
    await tester.tap(find.byTooltip('Go live with score'));
    await loadScore(tester);
    expect(
      tester.widget<PerformanceScreen>(find.byType(PerformanceScreen)).songs,
      hasLength(2),
    );
    await tester.drag(
      find.byKey(const ValueKey('music-stand-song-reader')),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Next Song  •'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
