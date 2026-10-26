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

    test(
      'transposes extended slash chords without mistaking 6/9 for a bass',
      () {
        expect(
          ChordTransposer.transposeChordPro(
            '[Am7/G]Sing [Cmaj7/E] [C6/9] [C6/9/E]',
            2,
          ),
          '[Bm7/A]Sing [Dmaj7/F#] [D6/9] [D6/9/F#]',
        );
        expect(
          ChordTransposer.transposeChordPro('[Bbmaj7/Ab]', -2),
          '[Abmaj7/Gb]',
        );
      },
    );

    test(
      'preserves chord-looking text inside directives and source comments',
      () {
        const source =
            '{comment: Play [C] softly}\n# [C] source note\n[C]Music';
        expect(
          ChordTransposer.transposeChordPro(source, 2),
          '{comment: Play [C] softly}\n# [C] source note\n[D]Music',
        );
      },
    );

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
