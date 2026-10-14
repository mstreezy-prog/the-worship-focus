import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chordpro_document.dart';

void main() {
  group('ChordProDocument', () {
    test('places a previously defined chord diagram at its directive', () {
      final document = ChordProDocument.parse(
        '''{define: G base-fret 1 frets 3 2 0 0 0 3 fingers 2 1 0 0 0 3}
[G]Amazing grace
{chord: G}
[C]How sweet the sound''',
      );

      expect(document.blocks, hasLength(3));
      expect(document.blocks[0], isA<ChordProTextBlock>());
      final diagram = document.blocks[1] as ChordProDiagramBlock;
      expect(diagram.definition.name, 'G');
      expect(diagram.definition.baseFret, 1);
      expect(diagram.definition.frets, [3, 2, 0, 0, 0, 3]);
      expect(diagram.definition.fingers, ['2', '1', '0', '0', '0', '3']);
      expect(document.blocks[2], isA<ChordProTextBlock>());
    });

    test('supports an inline chord definition and muted strings', () {
      final document = ChordProDocument.parse(
        '{chord: Bm base-fret 2 frets x 1 3 3 2 1 fingers x 1 3 4 2 1}',
      );

      final diagram = document.blocks.single as ChordProDiagramBlock;
      expect(diagram.definition.name, 'Bm');
      expect(diagram.definition.baseFret, 2);
      expect(diagram.definition.frets, [-1, 1, 3, 3, 2, 1]);
      expect(diagram.definition.fingers, ['x', '1', '3', '4', '2', '1']);
    });

    test('keeps an unknown chord directive non-rendering', () {
      final document = ChordProDocument.parse('{chord: Unmapped}\n[G]Lyrics');

      expect(document.blocks, hasLength(1));
      expect(document.blocks.single, isA<ChordProTextBlock>());
    });
  });
}
