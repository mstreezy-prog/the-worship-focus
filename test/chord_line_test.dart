import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chord_layout_engine.dart';
import 'package:worship_focus_studio/services/chordpro_parser.dart';
import 'package:worship_focus_studio/widgets/chord_line.dart';

void main() {
  testWidgets('uses CMG Sans for ChordPro lyrics and chord labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ChordLine(
              line: ChordLayoutLine(
                lyrics: 'Amazing grace',
                chords: [ChordToken('G', 0)],
              ),
            ),
          ),
        ),
      ),
    );

    final lyric = tester.widget<Text>(find.text('Amazing grace'));
    final chord = tester.widget<Text>(find.text('G'));

    expect(lyric.style?.fontFamily, 'CMG Sans');
    expect(lyric.style?.fontWeight, FontWeight.w500);
    expect(chord.style?.fontFamily, 'CMG Sans');
    expect(chord.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('spreads chord-only lines instead of stacking their labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ChordLine(
              line: ChordLayoutLine(
                lyrics: '',
                chords: [
                  ChordToken('D', 0),
                  ChordToken('G', 0),
                  ChordToken('AsusA', 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.text('G')).dx, greaterThan(0));
    expect(
      tester.getTopLeft(find.text('AsusA')).dx,
      greaterThan(tester.getTopLeft(find.text('G')).dx),
    );
  });
}
