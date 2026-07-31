import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chord_transposer.dart';

void main() {
  group('ChordTransposer', () {
    test('transposes chord roots while preserving qualities and lyrics', () {
      expect(
        ChordTransposer.transposeChordPro('[C]Grace [Am7]alone', 2),
        '[D]Grace [Bm7]alone',
      );
    });

    test('transposes slash chord bass notes', () {
      expect(ChordTransposer.transposeChord('G/B', 2), 'A/C#');
      expect(ChordTransposer.transposeChordPro('[G/B]Grace', 2), '[A/C#]Grace');
    });

    test('wraps downward and retains flat spelling preference', () {
      expect(ChordTransposer.transposeChord('C', -1), 'B');
      expect(ChordTransposer.transposeChord('Bb', 2), 'C');
    });

    test('does not change directives or lyrics', () {
      const source = '{title: C Song}\n[C]C is in the lyric';
      expect(
        ChordTransposer.transposeChordPro(source, 2),
        '{title: C Song}\n[D]C is in the lyric',
      );
    });
  });
}
