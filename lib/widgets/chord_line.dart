import 'package:flutter/material.dart';
import '../services/chord_layout_engine.dart';

class ChordLine extends StatelessWidget {
  final ChordLayoutLine line;

  const ChordLine({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final text = line.lyrics;

        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final charWidth = painter.width / (text.isEmpty ? 1 : text.length);

        return SizedBox(
          height: 40,
          child: Stack(
            children: [
              // chords
              ...line.chords.map((c) {
                return Positioned(
                  left: c.position * charWidth,
                  top: 0,
                  child: Text(
                    c.chord,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              }),

              // lyrics
              Positioned(bottom: 0, child: Text(text, style: style)),
            ],
          ),
        );
      },
    );
  }
}
