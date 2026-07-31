import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/services/chordpro_metadata.dart';

void main() {
  test('replaces title aliases without changing the chart body', () {
    expect(
      ChordProMetadata.setDirective('{t: Old}\n[C]Lyrics', 'title', 'New'),
      '{title: New}\n[C]Lyrics',
    );
  });

  test('adds and removes metadata directives', () {
    final withArtist = ChordProMetadata.setDirective(
      '{title: Song}\n[C]Lyrics',
      'artist',
      'Writer',
    );
    expect(withArtist, startsWith('{artist: Writer}\n'));
    expect(
      ChordProMetadata.setDirective(
        '{key: C}\n{title: Song}\n[C]Lyrics',
        'key',
        null,
      ),
      '{title: Song}\n[C]Lyrics',
    );
  });
}
