import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:worship_focus_studio/controllers/reader_annotation_controller.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/chordpro_directive.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';
import 'package:worship_focus_studio/services/chordpro_pdf_content.dart';
import 'package:worship_focus_studio/services/chordpro_performance_info.dart';
import 'package:worship_focus_studio/services/reader_document_service.dart';
import 'package:worship_focus_studio/widgets/chordpro_performance_view.dart';
import 'package:worship_focus_studio/widgets/preview_panel.dart';

List<String> labels(ChordProDocument document) => document.blocks
    .whereType<ChordProCommentBlock>()
    .map((block) => block.text)
    .toList();
List<String> lyrics(ChordProDocument document) => document.blocks
    .whereType<ChordProTextBlock>()
    .map((block) => block.line.lyrics)
    .toList();

void main() {
  test(
    'directives accept colons, whitespace, casing and argumentless forms',
    () {
      for (final line in [
        '{COMMENT: Verse 1}',
        '{comment Verse 1}',
        ' {comment : Verse 1} ',
      ]) {
        final directive = ChordProDirective.parse(line)!;
        expect(directive.name, 'comment');
        expect(directive.arguments, 'Verse 1');
      }
      expect(ChordProDirective.parse('{soc}')!.arguments, isEmpty);
      expect(ChordProDirective.parse('Sing {soc} now'), isNull);
    },
  );

  test('section headings support labels, aliases and sensible defaults', () {
    final document = ChordProDocument.parse('''{title: Test}
{start_of_verse: label="Verse 1"}
[C]Verse music
{end_of_verse}
{soc}
[G]Chorus music
{eoc}
{start_of_bridge label='Quiet bridge'}
[Am]Bridge music
{end_of_bridge}
{sov}
[C]Another verse
{eov}
{sob: Bridge 2}
[F]Another bridge
{eob}''');
    expect(labels(document), [
      'Verse 1',
      'Chorus',
      'Quiet bridge',
      'Verse',
      'Bridge 2',
    ]);
    expect(lyrics(document), [
      'Verse music',
      'Chorus music',
      'Bridge music',
      'Another verse',
      'Another bridge',
    ]);
  });

  test(
    'chorus repeats latest completed definition with optional new label',
    () {
      final document = ChordProDocument.parse('''{soc: Chorus 1}
[C]First chorus
{eoc}
{chorus}
{start_of_chorus: Chorus 2}
[G]Second chorus
{end_of_chorus}
{chorus: Final}''');
      expect(labels(document), ['Chorus 1', 'Chorus 1', 'Chorus 2', 'Final']);
      expect(lyrics(document), [
        'First chorus',
        'First chorus',
        'Second chorus',
        'Second chorus',
      ]);
      final anchors = ReaderAnnotationController.anchors(document.blocks);
      expect(anchors, hasLength(document.blocks.length));
      expect(anchors.values.toSet(), hasLength(document.blocks.length));
    },
  );

  test(
    'chorus without an earlier definition remains a visible musical cue',
    () {
      final document = ChordProDocument.parse(
        '{chorus: Final chorus}\n[C]Ending',
      );
      expect(labels(document), ['Final chorus']);
      expect(lyrics(document), ['Ending']);
    },
  );

  test('repeated chorus preserves comments and chord diagrams', () {
    final document = ChordProDocument.parse('''{define: C frets x 3 2 0 1 0}
{soc}
{ci: Build}
{chord: C}
[C]Sing
{eoc}
{chorus}''');
    expect(labels(document), ['Chorus', 'Build', 'Chorus', 'Build']);
    expect(document.blocks.whereType<ChordProDiagramBlock>(), hasLength(2));
    expect(ReaderAnnotationController.anchors(document.blocks), hasLength(8));
  });

  test('session transpose keeps sections, capo, and repeated music intact', () {
    final song = Song(
      id: 'song',
      title: 'Test',
      key: 'C',
      chordPro: '{key: C}\n{capo: 2}\n{soc}\n[Am7/G]Sing\n{eoc}\n{chorus}',
    );
    final displayed = ReaderDocumentService.transpose(song, 2);
    expect(displayed.chordPro, contains('{capo: 2}'));
    final document = ChordProDocument.parse(displayed.chordPro);
    expect(
      document.blocks.whereType<ChordProTextBlock>().map(
        (block) => block.line.chords.single.chord,
      ),
      ['Bm7/A', 'Bm7/A'],
    );
    final info = ChordProPerformanceInfo.fromSong(displayed);
    expect(info.key, 'D');
    expect(info.soundingKey, 'E');
    expect(song.chordPro, contains('[Am7/G]'));
  });

  test('capo reads direct and meta forms without changing the shape key', () {
    for (final directive in ['{capo: 2}', '{capo 2}', '{meta: capo 2}']) {
      final info = ChordProPerformanceInfo.fromSong(
        Song(
          id: 'song',
          title: 'Test',
          chordPro: '{key: C}\n$directive\n[C]Sing',
        ),
      );
      expect(info.key, 'C');
      expect(info.capo, 2);
      expect(info.soundingKey, 'D');
    }
    final minor = ChordProPerformanceInfo.fromSong(
      Song(
        id: 'minor',
        title: 'Test',
        key: 'Am',
        chordPro: '{capo: 3}\n[Am]Sing',
      ),
    );
    expect(minor.soundingKey, 'Cm');
  });

  test('invalid or absent capo is ignored, and zero is retained', () {
    for (final value in ['-2', 'two', '2.5', '']) {
      final info = ChordProPerformanceInfo.fromSong(
        Song(id: 'song', title: 'Test', chordPro: '{capo: $value}\n[C]Sing'),
      );
      expect(info.capo, isNull);
      expect(info.soundingKey, isNull);
    }
    final zero = ChordProPerformanceInfo.fromSong(
      Song(id: 'zero', title: 'Test', key: 'C', chordPro: '{capo: 0}\n[C]Sing'),
    );
    expect(zero.capo, 0);
    expect(zero.soundingKey, 'C');
    final noKey = ChordProPerformanceInfo.fromSong(
      Song(id: 'no-key', title: 'Test', chordPro: '{capo: 2}\n[C]Sing'),
    );
    expect(noKey.capoSummary, 'Capo: 2');
  });

  testWidgets('Music Stand shows sections, repeated lyrics and capo details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChordProPerformanceView(
            song: Song(
              id: 'song',
              title: 'Test',
              chordPro:
                  '{key: C}\n{capo: 2}\n{soc}\n[C]Sing together\n{eoc}\n{chorus: Final}',
            ),
            fontSize: 16,
            twoColumns: false,
            pageIndex: 0,
            layoutHeight: 1200,
          ),
        ),
      ),
    );
    expect(find.text('Chorus'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Sing together'), findsNWidgets(2));
    expect(find.text('Capo: 2'), findsOneWidget);
    expect(find.text('Sounding key: D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview and PDF include expanded sections and capo information',
    (tester) async {
      const source = '{key: C}\n{capo: 2}\n{soc}\n[C]Sing\n{eoc}\n{chorus}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPanel(
              song: Song(id: 'song', title: 'Test', chordPro: source),
            ),
          ),
        ),
      );
      expect(find.text('Chorus'), findsNWidgets(2));
      expect(find.text('Sing'), findsNWidgets(2));
      expect(find.textContaining('Sounding key: D'), findsOneWidget);
      final widgets = chordProPdfContent(source);
      expect(widgets, hasLength(5));
      expect(
        ((widgets.first as pw.Padding).child as pw.Text).text.toPlainText(),
        contains('Capo: 2'),
      );
      final pdf = pw.Document();
      pdf.addPage(pw.Page(build: (_) => pw.Column(children: widgets)));
      expect(await pdf.save(), isNotEmpty);
    },
  );
}
