import 'package:flutter/material.dart';

import '../models/song.dart';
import '../controllers/reader_annotation_controller.dart';
import '../models/score_annotation.dart';
import 'score_annotation_canvas.dart';
import '../services/chordpro_document.dart';
import '../services/reader_pagination.dart';
import '../services/chordpro_performance_info.dart';
import 'chord_diagram.dart';
import 'chord_line.dart';

/// A paged, stage-friendly ChordPro reader.
class ChordProPerformanceView extends StatelessWidget {
  const ChordProPerformanceView({
    required this.song,
    this.annotations,
    this.annotationTool = ScoreAnnotationTool.none,
    this.annotationColor = ScoreAnnotationColor.purple,
    this.widthScale = 1,
    required this.fontSize,
    required this.twoColumns,
    required this.pageIndex,
    this.layoutHeight,
    super.key,
  });

  final Song song;
  final ReaderAnnotationController? annotations;
  final ScoreAnnotationTool annotationTool;
  final ScoreAnnotationColor annotationColor;
  final double widthScale;
  final double fontSize;
  final bool twoColumns;
  final int pageIndex;
  final double? layoutHeight;

  @override
  Widget build(BuildContext context) {
    final document = ChordProDocument.parse(song.chordPro);
    final info = ChordProPerformanceInfo.fromSong(song);

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchors = ReaderAnnotationController.anchors(document.blocks);
        final pages = ReaderPagination.paginate(
          fontSize: fontSize,
          twoColumns: twoColumns && constraints.maxWidth >= 700,
          blocks: document.blocks,
          hasInfo: true,
          maxHeight: layoutHeight ?? constraints.maxHeight,
        );
        final visiblePage = pageIndex.clamp(0, pages.length - 1);
        final page = pages[visiblePage];

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page.showInformation) ...[
                  _SongInformation(song: song, info: info),
                  const SizedBox(height: 16),
                ],
                _ChordProPage(
                  columns: page.columns,
                  anchors: anchors,
                  annotations: annotations,
                  tool: annotationTool,
                  color: annotationColor,
                  widthScale: widthScale,
                  fontSize: fontSize,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Page ${visiblePage + 1} of ${pages.length}',
                    key: const ValueKey('chordpro-page-indicator'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChordProPage extends StatelessWidget {
  const _ChordProPage({
    required this.columns,
    required this.fontSize,
    required this.anchors,
    required this.annotations,
    required this.tool,
    required this.color,
    required this.widthScale,
  });

  final List<List<ChordProContentBlock>> columns;
  final double fontSize;
  final Map<ChordProContentBlock, String> anchors;
  final ReaderAnnotationController? annotations;
  final ScoreAnnotationTool tool;
  final ScoreAnnotationColor color;
  final double widthScale;

  @override
  Widget build(BuildContext context) {
    if (columns.every((column) => column.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < columns.length; index++) ...[
          if (index > 0) SizedBox(width: fontSize * 1.4),
          Expanded(
            child: _ChordProColumn(
              blocks: columns[index],
              fontSize: fontSize,
              anchors: anchors,
              annotations: annotations,
              tool: tool,
              color: color,
              widthScale: widthScale,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChordProColumn extends StatelessWidget {
  const _ChordProColumn({
    required this.blocks,
    required this.fontSize,
    required this.anchors,
    required this.annotations,
    required this.tool,
    required this.color,
    required this.widthScale,
  });

  final List<ChordProContentBlock> blocks;
  final double fontSize;
  final Map<ChordProContentBlock, String> anchors;
  final ReaderAnnotationController? annotations;
  final ScoreAnnotationTool tool;
  final ScoreAnnotationColor color;
  final double widthScale;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in blocks)
        Stack(
          children: [
            switch (block) {
              ChordProTextBlock(:final line) => ChordLine(
                line: line,
                fontSize: fontSize,
              ),
              ChordProDiagramBlock(:final definition) => Padding(
                padding: EdgeInsets.symmetric(vertical: fontSize * 0.35),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ChordDiagram(definition: definition, compact: true),
                ),
              ),
            },
            if (annotations != null)
              Positioned.fill(
                child: ScoreAnnotationCanvas(
                  key: ValueKey(anchors[block]),
                  annotations:
                      annotations!.annotations[anchors[block]] ?? const [],
                  tool: tool,
                  color: color,
                  widthScale: widthScale,
                  onChanged: (strokes) =>
                      annotations!.update(anchors[block]!, strokes),
                ),
              ),
          ],
        ),
    ],
  );
}

class _SongInformation extends StatelessWidget {
  const _SongInformation({required this.song, required this.info});

  final Song song;
  final ChordProPerformanceInfo info;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[
      if (info.key case final key?) _Detail(label: 'Key', value: key),
      if (info.tempo case final tempo?) _Detail(label: 'Tempo', value: tempo),
      if (info.timeSignature case final time?)
        _Detail(label: 'Time', value: time),
      if (info.songOrder case final order?)
        _Detail(label: 'Order', value: order),
    ];
    return Card.filled(
      key: const ValueKey('chordpro-song-information'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title, style: Theme.of(context).textTheme.headlineMedium),
            if (song.artist case final artist?) ...[
              const SizedBox(height: 2),
              Text(artist, style: Theme.of(context).textTheme.titleMedium),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 20, runSpacing: 8, children: details),
            ],
            for (final note in info.notes) ...[
              const SizedBox(height: 8),
              Text(note, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodyLarge,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
