import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/chordpro_document.dart';
import '../services/chordpro_performance_info.dart';
import 'chord_diagram.dart';
import 'chord_line.dart';

/// A paged, stage-friendly ChordPro reader.
class ChordProPerformanceView extends StatelessWidget {
  const ChordProPerformanceView({
    required this.song,
    required this.fontSize,
    required this.twoColumns,
    required this.pageController,
    required this.onPageChanged,
    required this.onPageCountChanged,
    super.key,
  });

  final Song song;
  final double fontSize;
  final bool twoColumns;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageCountChanged;

  @override
  Widget build(BuildContext context) {
    final document = ChordProDocument.parse(song.chordPro);
    final info = ChordProPerformanceInfo.fromSong(song);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _pagesFor(
          blocks: document.blocks,
          hasInfo: true,
          maxHeight: constraints.maxHeight,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) onPageCountChanged(pages.length);
        });

        return PageView.builder(
          key: const ValueKey('chordpro-page-reader'),
          controller: pageController,
          scrollDirection: Axis.vertical,
          itemCount: pages.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, pageIndex) {
            final page = pages[pageIndex];
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (page.showInformation) ...[
                    _SongInformation(song: song, info: info),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: _ChordProPage(
                      columns: page.columns,
                      fontSize: fontSize,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Page ${pageIndex + 1} of ${pages.length}',
                      key: const ValueKey('chordpro-page-indicator'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<_ChordProPageData> _pagesFor({
    required List<ChordProContentBlock> blocks,
    required bool hasInfo,
    required double maxHeight,
  }) {
    final lineHeight = fontSize * 2.75 + 4;
    final usableHeight = math.max(160.0, maxHeight - 56);
    final columnsPerPage = twoColumns ? 2 : 1;
    final linesPerColumn = math.max(2, (usableHeight / lineHeight).floor());
    final headerLines = hasInfo ? math.max(2, (150 / lineHeight).ceil()) : 0;
    final firstPageCapacity = math.max(2, linesPerColumn - headerLines);
    final pages = <_ChordProPageData>[];
    var start = 0;
    var capacity = firstPageCapacity;

    do {
      final columns = <List<ChordProContentBlock>>[];
      for (var column = 0; column < columnsPerPage; column++) {
        final pageColumn = <ChordProContentBlock>[];
        var used = 0;
        while (start < blocks.length) {
          final block = blocks[start];
          final cost = _blockCost(block, lineHeight);
          if (pageColumn.isNotEmpty && used + cost > capacity) break;
          pageColumn.add(block);
          used += cost;
          start++;
        }
        columns.add(pageColumn);
      }
      pages.add(
        _ChordProPageData(columns: columns, showInformation: pages.isEmpty),
      );
      capacity = linesPerColumn;
    } while (start < blocks.length);

    return pages;
  }

  int _blockCost(ChordProContentBlock block, double lineHeight) =>
      switch (block) {
        ChordProTextBlock() => 1,
        ChordProDiagramBlock() => math.max(4, (210 / lineHeight).ceil()),
      };
}

class _ChordProPageData {
  const _ChordProPageData({
    required this.columns,
    required this.showInformation,
  });

  final List<List<ChordProContentBlock>> columns;
  final bool showInformation;
}

class _ChordProPage extends StatelessWidget {
  const _ChordProPage({required this.columns, required this.fontSize});

  final List<List<ChordProContentBlock>> columns;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (columns.every((column) => column.isEmpty)) {
      return const SizedBox.expand();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < columns.length; index++) ...[
          if (index > 0) SizedBox(width: fontSize * 1.4),
          Expanded(
            child: _ChordProColumn(blocks: columns[index], fontSize: fontSize),
          ),
        ],
      ],
    );
  }
}

class _ChordProColumn extends StatelessWidget {
  const _ChordProColumn({required this.blocks, required this.fontSize});

  final List<ChordProContentBlock> blocks;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in blocks)
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
