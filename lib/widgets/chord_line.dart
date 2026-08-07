import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chord_layout_engine.dart';
import '../services/chordpro_parser.dart';

class ChordLine extends StatelessWidget {
  final ChordLayoutLine line;
  final double fontSize;

  const ChordLine({super.key, required this.line, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final lyricStyle = TextStyle(
      fontFamily: 'CMG Sans',
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
    final chordStyle = TextStyle(
      fontFamily: 'CMG Sans',
      fontWeight: FontWeight.w700,
      fontSize: fontSize * 1.1,
    );

    return LayoutBuilder(
      builder: (context, _) {
        final text = line.lyrics;
        if (text.isEmpty) {
          if (line.chords.isEmpty) return SizedBox(height: fontSize);
          return Padding(
            padding: EdgeInsets.symmetric(vertical: fontSize * 0.2),
            child: Wrap(
              spacing: fontSize * 0.8,
              runSpacing: fontSize * 0.35,
              children: [
                for (final chord in line.chords)
                  Text(chord.chord, style: chordStyle),
              ],
            ),
          );
        }

        double lyricOffsetFor(int position) {
          final boundedPosition = position.clamp(0, text.length).toInt();
          final prefix = text.substring(0, boundedPosition);
          final painter = TextPainter(
            text: TextSpan(text: prefix, style: lyricStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          return painter.width;
        }

        final chordPositions = <ChordToken, double>{};
        var nextChordLeft = 0.0;
        for (final chord in line.chords) {
          final painter = TextPainter(
            text: TextSpan(text: chord.chord, style: chordStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          final desiredLeft = lyricOffsetFor(chord.position);
          final left = math.max(desiredLeft, nextChordLeft);
          chordPositions[chord] = left;
          nextChordLeft = left + painter.width + fontSize * 0.45;
        }

        return SizedBox(
          height: fontSize * 2.75,
          child: Stack(
            children: [
              // chords
              ...line.chords.map((c) {
                return Positioned(
                  left: chordPositions[c]!,
                  top: 0,
                  child: Text(c.chord, style: chordStyle),
                );
              }),

              // lyrics
              Positioned(bottom: 0, child: Text(text, style: lyricStyle)),
            ],
          ),
        );
      },
    );
  }
}
