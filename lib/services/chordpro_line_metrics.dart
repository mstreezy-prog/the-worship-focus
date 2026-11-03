import 'dart:math' as math;

/// Shared by the reader's line layout and its page count calculation.
double chordProLineHeight(double lyricSize, double chordSize) => math.max(
  lyricSize * 2.75,
  (lyricSize + chordSize) * 1.25 + lyricSize * 0.1,
);
