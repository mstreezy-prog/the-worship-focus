import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:worship_focus_studio/controllers/reader_annotation_controller.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';
import 'package:worship_focus_studio/services/chordpro_pdf_content.dart';
import 'package:worship_focus_studio/services/chordpro_performance_info.dart';
import 'package:worship_focus_studio/services/reader_pagination.dart';
import 'package:worship_focus_studio/widgets/chordpro_comment.dart';
import 'package:worship_focus_studio/widgets/chordpro_performance_view.dart';
import 'package:worship_focus_studio/widgets/preview_panel.dart';

void main() {
  test('preserves comment aliases and styles in source order', () {
    final blocks = ChordProDocument.parse('''{title: Hidden metadata}
{Comment: Verse 1}
[C]First line
{c: Chorus}
[G]Second line
{comment_italic: Quietly}
{ci: Build}
{comment_box: Repeat}
{cb: End}
{highlight: Solo}
{comment: }
{unknown: Hidden}''').blocks;
    final comments = blocks.whereType<ChordProCommentBlock>().toList();
    expect(comments.map((block) => block.text), [
      'Verse 1',
      'Chorus',
      'Quietly',
      'Build',
      'Repeat',
      'End',
      'Solo',
    ]);
    expect(comments.map((block) => block.style), [
      ChordProCommentStyle.standard,
      ChordProCommentStyle.standard,
      ChordProCommentStyle.italic,
      ChordProCommentStyle.italic,
      ChordProCommentStyle.boxed,
      ChordProCommentStyle.boxed,
      ChordProCommentStyle.standard,
    ]);
    expect((blocks[1] as ChordProTextBlock).line.lyrics, 'First line');
    expect(blocks[2], same(comments[1]));
    expect((blocks[3] as ChordProTextBlock).line.chords.single.chord, 'G');
  });

  test('comments stay inline instead of duplicating in header notes', () {
    final info = ChordProPerformanceInfo.fromSong(
      Song(
        id: 'test',
        title: 'Test',
        chordPro:
            '{comment: Verse 1}\n{c: Intro}\n{note: Start quietly}\n[C]Music',
      ),
    );
    expect(info.notes, ['Start quietly']);
  });

  test('restoring comments preserves existing lyric annotation anchors', () {
    final before = ChordProDocument.parse('[C]Grace\n[C]Grace').blocks;
    final after = ChordProDocument.parse(
      '{comment: Verse}\n[C]Grace\n{c: Chorus}\n[C]Grace',
    ).blocks;
    final anchors = ReaderAnnotationController.anchors(after);
    expect(
      after.whereType<ChordProTextBlock>().map((block) => anchors[block]),
      ReaderAnnotationController.anchors(before).values,
    );
    expect(anchors.values.toSet(), hasLength(4));
  });

  for (final twoColumns in [false, true]) {
    test('keeps a section heading with music, two columns: $twoColumns', () {
      final blocks = ChordProDocument.parse(
        'Opening\n{comment: Chorus}\n\n[C]First chorus line\n[G]Ending',
      ).blocks;
      final pages = ReaderPagination.paginate(
        fontSize: 20,
        twoColumns: twoColumns,
        blocks: blocks,
        hasInfo: false,
        maxHeight: 240,
      );
      final columns = pages.expand((page) => page.columns).toList();
      expect(columns.expand((column) => column), blocks);
      final chorus = columns.singleWhere(
        (column) => column.contains(blocks[1]),
      );
      expect(chorus, containsAllInOrder([blocks[1], blocks[2], blocks[3]]));
      expect(columns.first, [blocks.first]);
    });
  }

  testWidgets('preview displays section titles between their lyric lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreviewPanel(
            song: Song(
              id: 'preview',
              title: 'Test',
              chordPro:
                  '{comment: Verse 1}\n[C]First line\n{c: Chorus}\n[G]Second line',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Verse 1'), findsOneWidget);
    expect(find.text('Chorus'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Verse 1')).dy,
      lessThan(tester.getTopLeft(find.text('First line')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Chorus')).dy,
      greaterThan(tester.getTopLeft(find.text('First line')).dy),
    );
  });

  testWidgets('Music Stand renders titles on their own chart pages', (
    tester,
  ) async {
    final song = Song(
      id: 'reader',
      title: 'Test',
      chordPro:
          '{comment: Verse 1}\n[C]First line\n{c: Chorus}\n[G]Second line',
    );
    Future<void> showPage(int index) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChordProPerformanceView(
              song: song,
              fontSize: 20,
              twoColumns: false,
              pageIndex: index,
              layoutHeight: 240,
            ),
          ),
        ),
      );
    }

    await showPage(0);
    expect(find.text('Verse 1'), findsOneWidget);
    expect(find.text('Chorus'), findsNothing);
    await showPage(1);
    expect(find.text('Chorus'), findsOneWidget);
    expect(find.text('Verse 1'), findsNothing);
    expect(find.byType(ChordProComment), findsOneWidget);
    expect(find.text('Page 2 of 2'), findsOneWidget);
  });

  test('PDF content includes comments between music lines', () async {
    final widgets = chordProPdfContent(
      '{title: Hidden}\n{c: Verse}\n[C]First\n{cb: Chorus}\n[G]Second',
    );
    expect(widgets, hasLength(4));
    expect(
      ((widgets.first as pw.Container).child as pw.Text).text.toPlainText(),
      'Verse',
    );
    expect(
      ((widgets[2] as pw.Container).child as pw.Text).text.toPlainText(),
      'Chorus',
    );
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (_) => pw.Column(children: widgets)));
    expect(await pdf.save(), isNotEmpty);
  });
}
