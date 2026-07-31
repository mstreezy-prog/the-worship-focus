import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chordpro_parser.dart';

void main() {
  group('ChordProParser', () {
    test('extracts chords at their lyric positions', () {
      final lines = ChordProParser.parse('[G]Amazing [C]grace');

      expect(lines, hasLength(1));
      expect(lines.single.lyrics, 'Amazing grace');
      expect(lines.single.chords.map((token) => token.chord), ['G', 'C']);
      expect(lines.single.chords.map((token) => token.position), [0, 8]);
    });

    test('omits ChordPro directives from rendered lines', () {
      final lines = ChordProParser.parse(
        '{title: Amazing Grace}\n[G]Amazing grace',
      );

      expect(lines, hasLength(1));
      expect(lines.single.lyrics, 'Amazing grace');
    });

    test('preserves an unmatched opening bracket as lyrics', () {
      final lines = ChordProParser.parse('A [broken line');

      expect(lines.single.lyrics, 'A [broken line');
      expect(lines.single.chords, isEmpty);
    });
  });
}
