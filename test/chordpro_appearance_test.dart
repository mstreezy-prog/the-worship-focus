import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/performance_preferences.dart';
import 'package:worship_focus_studio/models/song.dart';
import 'package:worship_focus_studio/screens/performance_screen.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';
import 'package:worship_focus_studio/services/reader_pagination.dart';
import 'package:worship_focus_studio/widgets/chord_line.dart';

void main() {
  for (final columns in [false, true]) {
    test(
      'larger chords repaginate without dropping content, two columns: $columns',
      () {
        final blocks = ChordProDocument.parse(
          List.generate(40, (i) => '[C]Line $i').join('\n'),
        ).blocks;
        List<ReaderPage> pages(double chordSize) => ReaderPagination.paginate(
          fontSize: 20,
          chordFontSize: chordSize,
          twoColumns: columns,
          blocks: blocks,
          hasInfo: true,
          maxHeight: 800,
        );
        expect(pages(50).length, greaterThan(pages(22).length));
        expect(
          pages(50).expand((page) => page.columns).expand((column) => column),
          blocks,
        );
      },
    );
  }

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('Music Stand chord controls are independent at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreen(
            songs: [
              Song(
                id: 'appearance',
                title: 'Grace',
                chordPro: '[C]Amazing [G]grace',
              ),
            ],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reader settings'));
      await tester.pumpAndSettle();
      expect(find.text('Lyric size'), findsOneWidget);
      final before = tester.widget<ChordLine>(find.byType(ChordLine).first);
      await tester.tap(find.byKey(const ValueKey('chordpro-chord-color-blue')));
      await tester.drag(
        find.byKey(const ValueKey('chordpro-chord-size')),
        const Offset(100, 0),
      );
      await tester.pump();
      final after = tester.widget<ChordLine>(find.byType(ChordLine).first);
      expect(after.chordFontSize, greaterThan(before.chordFontSize!));
      expect(after.fontSize, before.fontSize);
      expect(after.chordColor, Color(ChordProChordColor.blue.darkValue!));
      await tester.tap(find.byTooltip('Increase font size'));
      await tester.pump();
      final lyricChange = tester.widget<ChordLine>(
        find.byType(ChordLine).first,
      );
      expect(lyricChange.fontSize, before.fontSize + 2);
      expect(lyricChange.chordFontSize, after.chordFontSize);
      expect(lyricChange.chordColor, after.chordColor);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
