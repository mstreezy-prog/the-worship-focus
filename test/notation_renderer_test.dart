import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/performance_content.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/music_xml_viewer_screen.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/services/notation_renderer.dart';
import 'package:worship_focus_studio/widgets/music_xml_workspace.dart';

const _leadSheetXml = '''<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Melody</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type>
      </note>
    </measure>
  </part>
</score-partwise>''';

const _pianoXml = '''<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions><staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <note>
        <pitch><step>E</step><octave>5</octave></pitch>
        <duration>4</duration><type>whole</type><staff>1</staff>
      </note>
      <backup><duration>4</duration></backup>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>4</duration><type>whole</type><staff>2</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

Song _songWithBothArrangements() {
  return Song(
    id: 'notation-test',
    title: 'Notation Test',
    chordPro: '{title: Notation Test}',
    leadSheet: const MusicXmlArrangement(
      fileName: 'Notation-Test-Lead-Sheet.musicxml',
      sourceXml: _leadSheetXml,
      scoreTitle: 'Notation Test Lead Sheet',
      partCount: 1,
    ),
    fullPiano: const MusicXmlArrangement(
      fileName: 'Notation-Test-Full-Piano.musicxml',
      sourceXml: _pianoXml,
      scoreTitle: 'Notation Test Full Piano',
      partCount: 1,
    ),
  );
}

void main() {
  test('renderer parses a single-staff lead sheet', () {
    final document = NotationRenderer.parse(_leadSheetXml);

    expect(document.staffGroupCount, 1);
    expect(document.staffCount, 1);
  });

  test('renderer preserves both staves of a piano arrangement', () {
    final document = NotationRenderer.parse(_pianoXml);

    expect(document.staffGroupCount, 1);
    expect(document.staffCount, 2);
  });

  test('score theme uses CMG Sans for readable lyrics and chord labels', () {
    final theme = NotationRenderer.scoreTheme;

    expect(theme.lyricTextStyle?.fontFamily, 'CMG Sans');
    expect(theme.lyricTextStyle?.fontSize, 13);
    expect(theme.expressionTextStyle?.fontFamily, 'CMG Sans');
    expect(theme.expressionTextStyle?.fontSize, 16);
    expect(theme.expressionTextStyle?.fontWeight, FontWeight.w700);
  });

  testWidgets('viewer switches arrangements and exposes score controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicXmlArrangementType? transposedType;
    int? transposedSemitones;
    await tester.pumpWidget(
      MaterialApp(
        home: MusicXmlViewerScreen(
          song: _songWithBothArrangements(),
          initialType: MusicXmlArrangementType.leadSheet,
          onTranspose: (type, semitones) {
            transposedType = type;
            transposedSemitones = semitones;
          },
          onAnnotationsChanged: (_, _) {},
        ),
      ),
    );

    expect(find.text('Notation Test Lead Sheet'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Fit score'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Go live with score'), findsOneWidget);
    expect(find.text('Lead Sheet'), findsOneWidget);
    expect(find.text('Full Piano'), findsOneWidget);
    expect(find.byTooltip('Transpose score down'), findsOneWidget);
    expect(find.byTooltip('Transpose score up'), findsOneWidget);
    expect(find.byTooltip('Annotate with Apple Pencil'), findsOneWidget);
    expect(find.byTooltip('Highlight with Apple Pencil'), findsOneWidget);
    expect(
      find.byTooltip('Erase annotations with Apple Pencil'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Transpose score up'));
    await tester.pump();

    expect(transposedType, MusicXmlArrangementType.leadSheet);
    expect(transposedSemitones, 1);
    expect(find.text('Db major'), findsOneWidget);
    expect(find.text('+1 semitone'), findsOneWidget);

    await tester.tap(find.text('Full Piano'));
    await tester.pump();

    expect(find.text('Notation Test Full Piano'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait workspace keeps attached-score actions visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MusicXmlArrangementType? openedType;
    MusicXmlArrangementType? performedType;
    MusicXmlArrangementType? transposedType;
    int? transposedSemitones;
    final song = _songWithBothArrangements();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MusicXmlWorkspace(
            songs: [song],
            selectedSong: song,
            onSongSelected: (_) {},
            onImport: (_) {},
            onView: (type) => openedType = type,
            onPerform: (type) => performedType = type,
            onTranspose: (type, semitones) {
              transposedType = type;
              transposedSemitones = semitones;
            },
            onExport: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Open Lead Sheet').hitTestable(), findsOneWidget);
    expect(find.text('Open Full Piano').hitTestable(), findsOneWidget);
    expect(
      find.byTooltip('Transpose Lead Sheet down').hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Transpose Full Piano up').hitTestable(),
      findsOneWidget,
    );

    await tester.tap(find.text('Open Full Piano'));
    await tester.tap(find.text('Go live: Lead Sheet'));
    await tester.tap(find.byTooltip('Transpose Lead Sheet down'));

    expect(openedType, MusicXmlArrangementType.fullPiano);
    expect(performedType, MusicXmlArrangementType.leadSheet);
    expect(transposedType, MusicXmlArrangementType.leadSheet);
    expect(transposedSemitones, -1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'score performance uses the saved key and keeps arrangement choice visible',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = _songWithBothArrangements();
      final song = original.copyWith(
        leadSheet: original.leadSheet!.copyWith(transposeSemitones: 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [song],
            initialIndex: 0,
            initialContent: PerformanceContent.leadSheet,
            songNotes: {song.id: 'Start in D; repeat the final chorus.'},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Live mode'), findsOneWidget);
      expect(find.text('Start in D; repeat the final chorus.'), findsOneWidget);
      expect(find.textContaining('D major'), findsOneWidget);
      expect(find.text('ChordPro'), findsOneWidget);
      expect(find.text('Lead Sheet'), findsWidgets);
      expect(find.text('Full Piano'), findsOneWidget);
      expect(find.byTooltip('Previous score page'), findsOneWidget);
      expect(find.byTooltip('Next score page'), findsOneWidget);

      await tester.tap(find.text('ChordPro'));
      await tester.pump();
      expect(find.byTooltip('Decrease font size'), findsOneWidget);

      await tester.tap(find.text('Full Piano'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('performance-content-fullPiano')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );
}
