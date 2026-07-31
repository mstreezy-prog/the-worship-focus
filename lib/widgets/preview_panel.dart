import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/chord_layout_engine.dart';
import 'chord_line.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({required this.song, this.performance = false, super.key});

  final Song song;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final lines = ChordLayoutEngine.build(song.chordPro);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, performance ? 8 : 12, 16, 8),
          child: Text(
            performance ? song.title : 'Live preview',
            style: performance
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: lines.map((line) => ChordLine(line: line)).toList(),
          ),
        ),
      ],
    );
  }
}
