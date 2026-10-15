import 'package:flutter/foundation.dart';

/// One horizontal position in the service: chart pages and songs share a pager.
class MusicStandPage {
  const MusicStandPage({required this.songIndex, required this.chartPage});
  final int songIndex;
  final int chartPage;
}

class MusicStandPageSequence {
  MusicStandPageSequence(List<int> pageCounts)
    : pageCounts = List.unmodifiable(
        pageCounts.map((count) => count < 1 ? 1 : count),
      ) {
    pages = List.unmodifiable([
      for (var song = 0; song < this.pageCounts.length; song++)
        for (var page = 0; page < this.pageCounts[song]; page++)
          MusicStandPage(songIndex: song, chartPage: page),
    ]);
  }

  final List<int> pageCounts;
  late final List<MusicStandPage> pages;

  int indexFor(int songIndex, int chartPage) {
    final boundedSong = songIndex.clamp(0, pageCounts.length - 1);
    final boundedPage = chartPage.clamp(0, pageCounts[boundedSong] - 1);
    return pageCounts
            .take(boundedSong)
            .fold(0, (total, count) => total + count) +
        boundedPage;
  }

  bool hasSameLayout(MusicStandPageSequence other) =>
      listEquals(pageCounts, other.pageCounts);
}
