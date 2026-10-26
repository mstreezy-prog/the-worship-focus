import 'dart:math' as math;

import 'chordpro_document.dart';

class ReaderPagination {
  static List<ReaderPage> paginate({
    required double fontSize,
    required bool twoColumns,
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
    final pages = <ReaderPage>[];
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
          // Reserve space for a section's first music line as well as its label.
          // An empty column must still accept oversized content to make progress.
          var requiredCost = cost;
          if (block is ChordProCommentBlock) {
            var next = start + 1;
            while (next < blocks.length) {
              final following = blocks[next];
              requiredCost += _blockCost(following, lineHeight);
              next++;
              if (following is ChordProTextBlock &&
                  following.line.lyrics.trim().isEmpty &&
                  following.line.chords.isEmpty) {
                continue;
              }
              if (following is! ChordProCommentBlock) break;
            }
          }
          if (pageColumn.isNotEmpty && used + requiredCost > capacity) break;
          pageColumn.add(block);
          used += cost;
          start++;
        }
        columns.add(pageColumn);
      }
      pages.add(ReaderPage(columns: columns, showInformation: pages.isEmpty));
      capacity = linesPerColumn;
    } while (start < blocks.length);

    return pages;
  }

  static int _blockCost(ChordProContentBlock block, double lineHeight) =>
      switch (block) {
        ChordProCommentBlock() => 1,
        ChordProTextBlock() => 1,
        ChordProDiagramBlock() => math.max(4, (210 / lineHeight).ceil()),
      };
}

class ReaderPage {
  const ReaderPage({required this.columns, required this.showInformation});

  final List<List<ChordProContentBlock>> columns;
  final bool showInformation;
}
