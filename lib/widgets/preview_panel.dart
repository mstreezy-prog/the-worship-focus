import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/chordpro_document.dart';
import '../services/chordpro_performance_info.dart';
import 'chord_diagram.dart';
import 'chord_line.dart';
import 'chordpro_comment.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({
    required this.song,
    this.performance = false,
    this.fontSize = 16,
    this.scrollController,
    super.key,
  });

  final Song song;
  final bool performance;
  final double fontSize;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final document = ChordProDocument.parse(song.chordPro);
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
        if (ChordProPerformanceInfo.fromSong(song).capoSummary
            case final summary?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(summary),
          ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final block in document.blocks)
                switch (block) {
                  ChordProCommentBlock() => ChordProComment(
                    comment: block,
                    fontSize: fontSize,
                  ),
                  ChordProTextBlock(:final line) => ChordLine(
                    line: line,
                    fontSize: fontSize,
                  ),
                  ChordProDiagramBlock(:final definition) => Padding(
                    padding: EdgeInsets.symmetric(vertical: fontSize * 0.5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ChordDiagram(definition: definition),
                    ),
                  ),
                },
            ],
          ),
        ),
      ],
    );
  }
}
